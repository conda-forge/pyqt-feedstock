#!/bin/bash
# Shared build environment for the outputs built from the main PyQt6 sdist
# (build-pyqt.sh and build-pyqt-addon.sh). Source it from inside the pyqt
# source directory. Keeping this in one place guarantees that pyqt6 and its
# add-on outputs are configured identically.
#
# Sets:
#   SIP_COMMAND         command used to run sip-build
#   BUILD_PYTHON        python that can run on the build machine
#   PYQT_FEATURE_FLAGS  --disabled-feature flags shared by all outputs
#   CREATED_QMAKE       1 if ${PREFIX}/bin/qmake was created here, else 0

SIP_COMMAND="sip-build"
BUILD_PYTHON="${PYTHON}"
PYQT_FEATURE_FLAGS=""

if [[ $(uname) == "Linux" ]]; then
    # Resolve the activated toolchain before replacing any compiler shims.
    GXX_PATH=$(command -v "${GXX}")
    GCC_PATH=$(command -v "${GCC}")
    GCC_AR_PATH=$(command -v "${GCC_AR}")
    ln -sf "${GXX_PATH}" g++
    ln -sf "${GCC_PATH}" gcc
    ln -sf "${GCC_AR_PATH}" gcc-ar

    export LD=${GXX}
    export CC=${GCC}
    export CXX=${GXX}
    export PKG_CONFIG_EXECUTABLE=$(basename $(which pkg-config))

    chmod +x g++ gcc gcc-ar
    export PATH=${PWD}:${PATH}

    SYSROOT_FLAGS="-L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib"
    export CFLAGS="$SYSROOT_FLAGS $CFLAGS"
    export CXXFLAGS="$SYSROOT_FLAGS $CXXFLAGS"
    export LDFLAGS="$SYSROOT_FLAGS $LDFLAGS"
fi

if [[ $(uname) == "Darwin" ]]; then
    # Use xcode-avoidance scripts
    export PATH=$PREFIX/bin/xc-avoidance:$PATH

    # QNativeInterface X11/Wayland bindings are Linux-only and fail to compile on macOS.
    PYQT_FEATURE_FLAGS="${PYQT_FEATURE_FLAGS} --disabled-feature=PyQt_XCB"
    PYQT_FEATURE_FLAGS="${PYQT_FEATURE_FLAGS} --disabled-feature=PyQt_Wayland"
fi

# Set up cross-compilation (creates qmake wrapper and qt.conf)
source ${RECIPE_DIR}/setup-cross-compile.sh

CREATED_QMAKE=0
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # OpenGL ES2 detection is unreliable when probing the target Qt during cross
  # builds and can leave generated QtOpenGL sources referencing missing ES2
  # types on arm64 targets.
  PYQT_FEATURE_FLAGS="${PYQT_FEATURE_FLAGS} --disabled-feature=PyQt_OpenGL_ES2"
  SIP_COMMAND="$BUILD_PREFIX/bin/python -m sipbuild.tools.build"
  BUILD_PYTHON="${BUILD_PREFIX}/bin/python"
elif [[ ! -e "${PREFIX}/bin/qmake" ]]; then
  ln -s ${PREFIX}/bin/qmake6 ${PREFIX}/bin/qmake
  CREATED_QMAKE=1
fi

# Ensure that SIP's qmake-based feature probes can find headers supplied by
# host dependencies, including vulkan/vulkan.h on macOS.
export CPATH="${PREFIX}/include${CPATH:+:${CPATH}}"
