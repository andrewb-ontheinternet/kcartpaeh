#!/bin/sh
#
# Build heaptrack as a .rpm, using the current git checkout as the source.
# Intended to run inside tools/rpm/Dockerfile (a Fedora image with the
# necessary -devel packages), but will also work directly on a real Fedora
# machine that already has those packages installed.

set -e

srcdir=$(readlink -f "$1")
outdir=$(readlink -f "$2")

if [ -z "$srcdir" ] || [ -z "$outdir" ]; then
    echo "usage: $0 <srcdir> <outputdir>"
    exit 1
fi

if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "ERROR: cannot find rpmbuild in PATH"
    exit 1
fi

# Derive the package version from CMakeLists.txt, and the release from git,
# so the built RPM always matches exactly what's checked out.
version=$(awk -F'[ )]+' '
    /^set\(HEAPTRACK_VERSION_MAJOR / { major = $2 }
    /^set\(HEAPTRACK_VERSION_MINOR / { minor = $2 }
    /^set\(HEAPTRACK_VERSION_PATCH / { patch = $2 }
    END { print major "." minor "." patch }
' "$srcdir/CMakeLists.txt")

gitdesc=$(git -C "$srcdir" describe --tags --long)
commitcount=$(echo "$gitdesc" | sed -E 's/^.*-([0-9]+)-g[0-9a-f]+$/\1/')
commithash=$(echo "$gitdesc" | sed -E 's/^.*-g([0-9a-f]+)$/\1/')
release="0.$commitcount.g$commithash"

echo "Building heaptrack $version-$release (from git describe: $gitdesc)"

rpmdev-setuptree

tarball="$HOME/rpmbuild/SOURCES/heaptrack-$version.tar.gz"
git -C "$srcdir" archive --prefix="heaptrack-$version/" -o "$tarball" HEAD

cp "$srcdir/tools/rpm/heaptrack.spec" "$HOME/rpmbuild/SPECS/heaptrack.spec"

rpmbuild -ba "$HOME/rpmbuild/SPECS/heaptrack.spec" \
    --define "_heaptrack_version $version" \
    --define "_heaptrack_release $release" \
    --define "_heaptrack_gitdesc $gitdesc" \
    --define "_heaptrack_changelog_date $(date '+%a %b %d %Y')"

mkdir -p "$outdir"
cp "$HOME"/rpmbuild/RPMS/*/*.rpm "$outdir/"
cp "$HOME"/rpmbuild/SRPMS/*.rpm "$outdir/"

# When run as root in a container (needed because rpmdev-setuptree requires a
# real passwd entry, which an arbitrary `docker run --user` UID won't have),
# hand the output back to the host user.
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    chown -R "$HOST_UID:$HOST_GID" "$outdir"
fi

echo "RPMs written to $outdir:"
ls -la "$outdir"
