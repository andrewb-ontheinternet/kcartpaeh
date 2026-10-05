#
# Adapted from Fedora's own heaptrack.spec
# (https://src.fedoraproject.org/rpms/heaptrack) to build from a local git
# checkout. Version/Release/changelog values are injected by
# tools/build_rpm.sh via --define so this spec stays in sync with whatever
# commit is checked out, instead of a pinned upstream release tarball.
#
Name:    heaptrack
Version: %{_heaptrack_version}
Release: %{_heaptrack_release}%{?dist}
Summary: A heap memory profiler for Linux

License: Apache-2.0 AND BSD-3-Clause AND BSL-1.0 AND GPL-2.0-or-later AND LGPL-2.1-only AND LGPL-2.1-or-later AND MIT
URL:     https://invent.kde.org/sdk/heaptrack/

Source0: %{name}-%{version}.tar.gz

BuildRequires:  desktop-file-utils

BuildRequires:  extra-cmake-modules
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kitemmodels-devel
BuildRequires:  kf6-threadweaver-devel
BuildRequires:  kf6-kconfigwidgets-devel
BuildRequires:  kf6-kio-devel
BuildRequires:  kf6-kiconthemes-devel

BuildRequires:  kdiagram-devel

BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtsvg-devel

BuildRequires:  boost-devel
BuildRequires:  libunwind-devel
BuildRequires:  libdwarf-devel
BuildRequires:  elfutils-devel
BuildRequires:  libzstd-devel
BuildRequires:  sparsehash-devel
BuildRequires:  zlib-devel

# no libunwind on s390(x)
ExcludeArch:    s390 s390x

%description
Heaptrack traces all memory allocations and annotates these events with stack
traces. Dedicated analysis tools then allow you to interpret the heap memory
profile to:
- find hotspots that need to be optimized to reduce the memory footprint of your
  application
- find memory leaks, i.e. locations that allocate memory which is never
  deallocated
- find allocation hotspots, i.e. code locations that trigger a lot of memory
  allocation calls
- find temporary allocations, which are allocations that are directly followed
  by their deallocation


%prep
%autosetup -n %{name}-%{version}


%build
%cmake_kf6 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
%if "%{?_lib}" == "lib64"
  %{?_cmake_lib_suffix64}
%endif

%cmake_build


%install
%cmake_install

%find_lang heaptrack --with-qt --all-name


%check
desktop-file-validate %{buildroot}%{_datadir}/applications/org.kde.heaptrack.desktop


%files -f heaptrack.lang
%license LICENSES/GPL-2.0-or-later.txt
%{_bindir}/heaptrack
%{_bindir}/heaptrack_gui
%{_bindir}/heaptrack_print
%{_datadir}/applications/org.kde.heaptrack.desktop
%{_includedir}/heaptrack_api.h
%{_datadir}/metainfo/org.kde.heaptrack.appdata.xml
%dir %{_libdir}/heaptrack/
%{_libdir}/heaptrack/libheaptrack_inject.so
%{_libdir}/heaptrack/libheaptrack_preload.so
%{_libdir}/heaptrack/libexec/heaptrack_interpret
%{_libdir}/heaptrack/libexec/heaptrack_env
%{_datadir}/icons/hicolor/*/apps/heaptrack*


%changelog
* %{_heaptrack_changelog_date} Local Build <local@localhost> - %{version}-%{release}
- Local build from git %{_heaptrack_gitdesc}
