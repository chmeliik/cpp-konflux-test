FROM registry.access.redhat.com/ubi9/ubi:9.6-1753978585

RUN dnf -y install cmake gcc-c++ git-core

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ARG JOBS=16
ARG VERBOSE_LOGS=ON
ARG LTO_ENABLE=ON
ARG LTO_CXX_FLAGS="-flto=auto -ffat-lto-objects -march=haswell"
ARG LTO_LD_FLAGS="-flto=auto -ffat-lto-objects"
ARG ov_tokenizers_branch=releases/2025/1

RUN git clone https://github.com/openvinotoolkit/openvino_tokenizers.git /openvino_tokenizers && \
    cd /openvino_tokenizers && \
    git checkout $ov_tokenizers_branch && \
    git submodule update --init --recursive

WORKDIR /openvino_tokenizers/build

RUN cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_VERBOSE_MAKEFILE="${VERBOSE_LOGS}" \
        -DCMAKE_CXX_FLAGS=" ${LTO_CXX_FLAGS} " \
        -DCMAKE_SHARED_LINKER_FLAGS="${LTO_LD_FLAGS}"
