set -exou

pushd pyqt_webengine

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
fi

sip-build \
--verbose \
--no-make

pushd build

# For some reason SIP does not add the QtPrintSupport headers
cat QtWebEngineWidgets/Makefile | sed -r 's|INCPATH       =(.*)|INCPATH       =\1 -I'$PREFIX/include/qt/QtPrintSupport'|' > QtWebEngineWidgets/Makefile.temp
rm QtWebEngineWidgets/Makefile
mv QtWebEngineWidgets/Makefile.temp QtWebEngineWidgets/Makefile

CPATH=$PREFIX/include make -j$CPU_COUNT
make install
