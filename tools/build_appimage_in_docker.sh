#!/bin/sh
#
# Build a heaptrack AppImage locally using Docker.
#
# Usage: tools/build_appimage_in_docker.sh [outputdir]
#
# The resulting AppImage (and the intermediate CMake build directory, which
# is reused on subsequent runs to speed up rebuilds) are written to
# <outputdir>, which defaults to ./output in the repository root.

set -e

srcdir=$(cd "$(dirname "$0")/.." && pwd)
outdir=$(mkdir -p "${1:-$srcdir/output}" && cd "${1:-$srcdir/output}" && pwd)

docker build -t heaptrack-appimage -f "$srcdir/tools/Dockerfile" "$srcdir/tools"

docker run --rm \
    -v "$srcdir:/src:ro" \
    -v "$outdir:/output" \
    --user "$(id -u):$(id -g)" \
    -e "HOME=/output" \
    heaptrack-appimage \
    /src/tools/build_appimage.sh /src /output/build-appimage /output

echo "AppImage written to $outdir"
