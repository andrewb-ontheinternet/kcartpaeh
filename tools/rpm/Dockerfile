#
# Fedora image with everything needed to build heaptrack as an .rpm.
#
# Package list mirrors Fedora's own heaptrack.spec (see
# https://src.fedoraproject.org/rpms/heaptrack), adjusted for building
# straight from a local git checkout instead of a released tarball.
#
FROM fedora:latest

RUN dnf install -y --setopt=install_weak_deps=False \
        rpm-build rpmdevtools cmake gcc-c++ git desktop-file-utils \
        extra-cmake-modules kf6-rpm-macros \
        kf6-kcoreaddons-devel kf6-ki18n-devel kf6-kitemmodels-devel \
        kf6-threadweaver-devel kf6-kconfigwidgets-devel kf6-kio-devel kf6-kiconthemes-devel \
        kdiagram-devel qt6-qtbase-devel qt6-qtsvg-devel \
        boost-devel libunwind-devel libdwarf-devel elfutils-devel libzstd-devel \
        sparsehash-devel zlib-devel \
    && dnf clean all
