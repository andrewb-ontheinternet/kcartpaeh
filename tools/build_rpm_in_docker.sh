#!/bin/sh
#
# Build a heaptrack .rpm for Fedora locally using Docker.
#
# Usage: tools/build_rpm_in_docker.sh [outputdir]
#
# The resulting RPMs (the binary package, -debuginfo, -debugsource, and a
# .src.rpm) are written to <outputdir>, which defaults to ./output-rpm in the
# repository root.

set -e

srcdir=$(cd "$(dirname "$0")/.." && pwd)
outdir=$(mkdir -p "${1:-$srcdir/output-rpm}" && cd "${1:-$srcdir/output-rpm}" && pwd)

docker build -t heaptrack-rpm-fedora -f "$srcdir/tools/rpm/Dockerfile" "$srcdir/tools/rpm"

# Runs as root in the container: rpmdev-setuptree needs a real passwd entry
# for $HOME, which an arbitrary `--user $(id -u):$(id -g)` UID won't have.
# tools/build_rpm.sh chowns the output back to HOST_UID/HOST_GID afterwards.
docker run --rm \
    -v "$srcdir:/src:ro" \
    -v "$outdir:/output" \
    -e "HOST_UID=$(id -u)" \
    -e "HOST_GID=$(id -g)" \
    heaptrack-rpm-fedora \
    /src/tools/build_rpm.sh /src /output

echo "RPMs written to $outdir"
