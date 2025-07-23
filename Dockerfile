FROM registry.access.redhat.com/ubi9/ubi:9.6

RUN dnf -y install cmake gcc-c++ git-core python3-devel

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ARG JOBS=16
ARG VERBOSE_LOGS=ON
ARG LTO_ENABLE=ON
ARG LTO_CXX_FLAGS="-flto=auto -ffat-lto-objects -march=haswell"
ARG LTO_LD_FLAGS="-flto=auto -ffat-lto-objects"

ARG ov_tokenizers_branch=releases/2025/1
ARG ov_source_branch=releases/2025/1
ARG ov_contrib_branch=releases/2025/1
ARG ov_source_org=opendatahub-io
ARG ov_contrib_org=opendatahub-io
ARG ov_use_binary=0
ARG debug_bazel_flags="--strip=always --define MEDIAPIPE_DISABLE=0 --define PYTHON_DISABLE=0 --config=mp_on_py_on --verbose_failures --//:distro=redhat --local_ram_resources=23552 --local_cpu_resources=16"

################### BUILD OPENVINO FROM SOURCE - buildarg ov_use_binary=0  ############################
# hadolint ignore=DL3041
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && dnf install -y gflags-devel gflags json-devel fdupes && \
    dnf clean all
# hadolint ignore=DL3003
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; git clone https://github.com/$ov_source_org/openvino.git /openvino && cd /openvino && git checkout $ov_source_branch && git submodule update --init --recursive
RUN if [ "$ov_use_binary" == "0" ]; then true ; else exit 0 ; fi ; if ! [[ $debug_bazel_flags == *"py_off"* ]]; then true ; else exit 0 ; fi ; pip3 install --no-cache-dir -r /openvino/src/bindings/python/wheel/requirements-dev.txt
WORKDIR /openvino
COPY openvino-lto.patch .
RUN if [ "$ov_use_binary" == "0" ]; then patch -p1 < openvino-lto.patch ; rm -f openvino-lto.patch ; fi
WORKDIR /openvino/build
RUN if [ "$ov_use_binary" == "0" ] && [[ $debug_bazel_flags == *"PYTHON_DISABLE=1"* ]]; then true ; else exit 0 ; fi ; if ! [[ $debug_bazel_flags == *"PYTHON_DISABLE=1"* ]]; then true ; else exit 0 ; fi ; cmake -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE -DCMAKE_VERBOSE_MAKEFILE="${VERBOSE_LOGS}" -DENABLE_LTO=${LTO_ENABLE} -DENABLE_PYTHON=ON -DENABLE_INTEL_NPU=OFF -DENABLE_SAMPLES=0 -DCMAKE_CXX_FLAGS=" -Wno-error=parentheses  ${LTO_CXX_FLAGS} " -DCMAKE_SHARED_LINKER_FLAGS="${LTO_LD_FLAGS}" ..
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; cmake -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" -DCMAKE_VERBOSE_MAKEFILE="${VERBOSE_LOGS}" -DENABLE_LTO=${LTO_ENABLE} -DENABLE_SAMPLES=0 -DENABLE_INTEL_NPU=OFF -DCMAKE_CXX_FLAGS=" -Wno-error=parentheses ${LTO_CXX_FLAGS} " -DCMAKE_SHARED_LINKER_FLAGS="${LTO_LD_FLAGS}" ..
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; make --jobs=$JOBS
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; make install
RUN if [ "$ov_use_binary" == "0" ] ; then true ; else exit 0 ; fi ; \
    mkdir -p /opt/intel/openvino/extras && \
    mkdir -p /opt/intel/openvino && \
    ln -s /openvino/inference-engine/temp/opencv_*/opencv /opt/intel/openvino/extras && \
    ln -s /usr/local/runtime /opt/intel/openvino && \
    ln -s /openvino/scripts/setupvars/setupvars.sh /opt/intel/openvino/setupvars.sh && \
    ln -s /opt/intel/openvino /opt/intel/openvino_2025
RUN if [ "$ov_use_binary" == "0" ]; then true ; else exit 0 ; fi ; if ! [[ $debug_bazel_flags == *"py_off"* ]]; then true ; else exit 0 ; fi ; mkdir -p /opt/intel/openvino && cp -r /openvino/bin/intel64/Release/python /opt/intel/openvino/
RUN if [ "$ov_use_binary" == "0" ]; then true ; else exit 0 ; fi ; if ! [[ $debug_bazel_flags == *"py_off"* ]]; then true ; else exit 0 ; fi ; cp -r /openvino/tools/ovc/* /opt/intel/openvino/python
################## END OF OPENVINO SOURCE BUILD ######################

ENV OpenVINO_DIR=/opt/intel/openvino/runtime/cmake
ENV LD_LIBRARY_PATH=/ovms/lib
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/opt/intel/openvino/runtime/lib/intel64/:/opt/opencv/lib/:/opt/intel/openvino/runtime/3rdparty/tbb/lib/

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
