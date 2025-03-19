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

    # Drop CDTs. Patch 0004 now takes from $PREFIX.
    # Will we still need this for something else though?
    SYSROOT_FLAGS="-L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib"
    export CFLAGS="$SYSROOT_FLAGS $CFLAGS"
    export CXXFLAGS="$SYSROOT_FLAGS $CXXFLAGS"
    export LDFLAGS="$SYSROOT_FLAGS $LDFLAGS"
fi

if [[ $(uname) == "Darwin" ]]; then
    # Use xcode-avoidance scripts
    export PATH=$PREFIX/bin/xc-avoidance:$PATH
    if [[ ${HOST} =~ arm64.* ]]; then
        EXTRAFLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_Vulkan"
    fi
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  SIP_COMMAND="$BUILD_PREFIX/bin/python -m sipbuild.tools.build"
  SITE_PKGS_PATH=$($PREFIX/bin/python -c 'import site;print(site.getsitepackages()[0])')
  EXTRA_FLAGS="${EXTRA_FLAGS} --target-dir $SITE_PKGS_PATH"
  ln -s ${BUILD_PREFIX}/bin/qmake6 ${BUILD_PREFIX}/bin/qmake
fi
ln -s ${PREFIX}/bin/qmake6 ${PREFIX}/bin/qmake

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
  cat Makefile | sed -r 's|\t(.*)sip-distinfo(.*)|\t'$BUILD_PREFIX/bin/python' -m sipbuild.distinfo.main \2|' > Makefile.temp
  rm Makefile
  mv Makefile.temp Makefile
fi

CPATH=$PREFIX/include make -j$CPU_COUNT
make install
