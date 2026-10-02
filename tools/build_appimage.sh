#!/bin/sh

set -e

srcdir=$(readlink -f "$1")
buildir=$(readlink -f "$2")
outdir=$(readlink -f "${3:-$(dirname "$buildir")}")

if [ -z "$srcdir" ] || [ -z "$buildir" ]; then
    echo "usage: $0 <srcdir> <builddir> [outputdir]"
    exit 1
fi

gitversion=$(git -C "$srcdir" describe)

ZSTD=$(which zstd)

if [ -z "$ZSTD" ]; then
    echo "ERROR: cannot find zstd in PATH"
    exit 1
fi

if [ -z "$(which linuxdeploy)" ]; then
    echo "ERROR: cannot find linuxdeploy in PATH"
    exit 1
fi

# librustc_demangle.so, built from https://github.com/rust-lang/rustc-demangle
# by tools/Dockerfile. heaptrack dlopen()s this at runtime (see
# src/interpret/demangler.cpp) to demangle Rust symbol names.
RUSTC_DEMANGLE_LIB="${RUSTC_DEMANGLE_LIB:-/opt/rustc-demangle/librustc_demangle.so}"

if [ ! -f "$RUSTC_DEMANGLE_LIB" ]; then
    echo "ERROR: cannot find librustc_demangle.so at $RUSTC_DEMANGLE_LIB"
    exit 1
fi

. /opt/rh/gcc-toolset-14/enable

mkdir -p "$buildir" && cd "$buildir"
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH=/opt/rh/gcc-toolset-14/root/ \
    -DCMAKE_BUILD_TYPE=Release  -DAPPIMAGE_BUILD=ON "$srcdir"
make -j$(nproc)
rm -Rf appdir
make DESTDIR=appdir install

# copy the zstd binary into the app image
cp $ZSTD ./appdir/usr/bin/zstd

# Ensure we prefer the bundled libs also when calling dlopen, cf.: https://github.com/KDAB/hotspot/issues/89
# We still allow a user-supplied QT_PLUGIN_PATH to be searched *after* the bundled
# plugins though (rather than wiping it outright), so e.g. a host-installed platform
# theme plugin (QT_QPA_PLATFORMTHEME=qt5ct/qt6ct) can still be found and loaded.
mv "./appdir/usr/bin/heaptrack_gui" "./appdir/usr/bin/heaptrack_gui_bin"
cat << WRAPPER_SCRIPT > ./appdir/usr/bin/heaptrack_gui
#!/bin/bash
f="\$(readlink -f "\${0}")"
d="\$(dirname "\$f")"
export QT_PLUGIN_PATH="\$d/../plugins\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}"
LD_LIBRARY_PATH="\$d/../lib:\$LD_LIBRARY_PATH" "\$d/heaptrack_gui_bin" "\$@"
WRAPPER_SCRIPT
chmod +x ./appdir/usr/bin/heaptrack_gui

mv "./appdir/usr/lib/heaptrack/libexec/heaptrack_interpret" "./appdir/usr/lib/heaptrack/libexec/heaptrack_interpret_bin"
cat << WRAPPER_SCRIPT > ./appdir/usr/lib/heaptrack/libexec/heaptrack_interpret
#!/bin/bash
f="\$(readlink -f "\${0}")"
d="\$(dirname "\$f")"
LD_LIBRARY_PATH="\$d/../../:\$LD_LIBRARY_PATH" "\$d/heaptrack_interpret_bin" "\$@"
WRAPPER_SCRIPT
chmod +x ./appdir/usr/lib/heaptrack/libexec/heaptrack_interpret

# include breeze icons
mkdir -p "appdir/usr/share/icons/breeze"
cp -v "/usr/share/icons/breeze/breeze-icons.rcc" "appdir/usr/share/icons/breeze/"

# use the shell script as AppRun entry point
# also make sure we find the bundled zstd
cat << WRAPPER_SCRIPT > ./appdir/AppRun
#!/bin/bash
f="\$(readlink -f "\${0}")"
d="\$(dirname "\$f")"
bin="\$d/usr/bin"
PATH="\$PATH:\$bin" "\$bin/heaptrack" "\$@"
WRAPPER_SCRIPT
chmod +x ./appdir/AppRun

# tell the linuxdeploy qt plugin to include these platform plugins
export EXTRA_PLATFORM_PLUGINS="libqoffscreen.so;libqwayland-generic.so"

mkdir -p appdir/usr/plugins/wayland-shell-integration/
cp /usr/plugins/wayland-shell-integration/libxdg-shell.so appdir/usr/plugins/wayland-shell-integration/

linuxdeploy --appdir appdir --plugin qt \
    -e "./appdir/usr/lib/heaptrack/libexec/heaptrack_interpret_bin" \
    -e "./appdir/usr/lib/heaptrack/libheaptrack_preload.so" \
    -e "./appdir/usr/lib/heaptrack/libheaptrack_inject.so" \
    -e "./appdir/usr/bin/heaptrack_gui_bin" \
    -e "./appdir/usr/bin/zstd" \
    -l "/usr/lib64/libz.so.1" \
    -l /usr/lib64/libharfbuzz.so.0 \
    -l /usr/lib64/libfreetype.so.6 \
    -l /usr/lib64/libfontconfig.so.1 \
    -l /usr/lib64/libwayland-egl.so \
    -l "$RUSTC_DEMANGLE_LIB" \
    -i "$srcdir/src/analyze/gui/128-apps-heaptrack.png" --icon-filename=heaptrack \
    -d "./appdir/usr/share/applications/org.kde.heaptrack.desktop"

# The qt plugin above generates an apprun hook that unconditionally forces
# QT_QPA_PLATFORMTHEME=gtk2 on GNOME/XFCE-like desktops (clobbering anything the
# user set, and "gtk2" isn't even a real Qt6 platform theme). Patch it to only
# apply that default if QT_QPA_PLATFORMTHEME isn't already set, so e.g.
# QT_QPA_PLATFORMTHEME=qt5ct/qt6ct exported by the user is respected.
qt_hook="appdir/apprun-hooks/linuxdeploy-plugin-qt-hook.sh"
if [ -f "$qt_hook" ]; then
    sed -i 's/export QT_QPA_PLATFORMTHEME=gtk2/: "${QT_QPA_PLATFORMTHEME:=gtk2}"; export QT_QPA_PLATFORMTHEME/' "$qt_hook"
else
    echo "WARNING: $qt_hook not found, QT_QPA_PLATFORMTHEME may be overridden on some desktops" >&2
fi

appimagetool appdir

mkdir -p "$outdir"
mv Heaptrack*x86_64.AppImage "$outdir/heaptrack-$gitversion-x86_64.AppImage"
