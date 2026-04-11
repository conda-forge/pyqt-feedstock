set -exou

pushd pyqt
cp LICENSE ..

SIP_COMMAND="sip-build"
EXTRA_FLAGS=""

if [[ $(uname) == "Linux" ]]; then
    USED_BUILD_PREFIX=${BUILD_PREFIX:-${PREFIX}}
    echo USED_BUILD_PREFIX=${BUILD_PREFIX}

    ln -s ${GXX} g++ || true
    ln -s ${GCC} gcc || true
    ln -s ${USED_BUILD_PREFIX}/bin/${HOST}-gcc-ar gcc-ar || true

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
    EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_XCB"
    EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_Wayland"

    if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
      EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_Vulkan"
      EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_OpenGL_ES2"
    fi
fi

# Set up cross-compilation for macOS (creates qmake wrapper and qt.conf)
source ${RECIPE_DIR}/setup-cross-compile.sh

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  SIP_COMMAND="$BUILD_PREFIX/bin/python -m sipbuild.tools.build"
  SITE_PKGS_PATH=$($PREFIX/bin/python -c 'import site;print(site.getsitepackages()[0])')
  EXTRA_FLAGS="${EXTRA_FLAGS} --target-dir $SITE_PKGS_PATH"
else
  ln -s ${PREFIX}/bin/qmake6 ${PREFIX}/bin/qmake
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  echo "" > sip/QtOpenGL/qopenglfunctions_es2.sip
fi

$SIP_COMMAND \
--verbose \
--confirm-license \
--no-make \
$EXTRA_FLAGS

pushd build

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Make sure BUILD_PREFIX sip-distinfo is called instead of the HOST one
  cat Makefile | sed -r 's|\t(.*)sip-distinfo(.*)|\t'$BUILD_PREFIX/bin/python' -m sipbuild.tools.distinfo \2|' > Makefile.temp
  rm Makefile
  mv Makefile.temp Makefile
fi

CPATH=$PREFIX/include make -j$CPU_COUNT
make install

if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    # Verify the built libraries are arm64
    echo "Verifying PyQt6 extension architectures..."
    for lib in $(find $PREFIX/lib/python*/site-packages/PyQt6 -name "*.so" 2>/dev/null); do
        if ! file "$lib" | grep -q "arm64"; then
            echo "ERROR: $lib is not arm64!"
            file "$lib"
            exit 1
        fi
    done
    echo "All PyQt6 extensions verified as arm64"
fi
