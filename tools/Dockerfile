#
# SPDX-FileCopyrightText: Milian Wolff <milian.wolff@kdab.com>
# SPDX-FileCopyrightText: 2024 Klarälvdalens Datakonsult AB, a KDAB Group company, info@kdab.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
#

#
# NOTE: this relies on the docker image also used by hotspot, see:
#       https://github.com/KDAB/hotspot/tree/master/scripts/appimage
#

# Build librustc_demangle.so from https://github.com/rust-lang/rustc-demangle.
# heaptrack dlopen()s this library at runtime (see src/interpret/demangler.cpp)
# to demangle Rust symbol names. It is built in its own stage so the final
# image doesn't need to carry a Rust toolchain.
FROM ghcr.io/kdab/kdesrc-build:latest AS rustc-demangle-builder

RUN dnf install -y rust cargo git

ARG RUSTC_DEMANGLE_REF=rustc-demangle-v0.1.28

RUN git clone --depth 1 --branch "${RUSTC_DEMANGLE_REF}" \
        https://github.com/rust-lang/rustc-demangle.git /tmp/rustc-demangle \
    && cd /tmp/rustc-demangle \
    && cargo build --release -p rustc-demangle-capi \
    && mkdir -p /opt/rustc-demangle \
    && cp target/release/librustc_demangle.so /opt/rustc-demangle/librustc_demangle.so \
    && rm -rf /tmp/rustc-demangle "$CARGO_HOME/registry"

FROM ghcr.io/kdab/kdesrc-build:latest

RUN dnf update -y && dnf install -y epel-release && dnf update -y && dnf install -y libunwind-devel zstd

COPY --from=rustc-demangle-builder /opt/rustc-demangle/librustc_demangle.so /opt/rustc-demangle/librustc_demangle.so
