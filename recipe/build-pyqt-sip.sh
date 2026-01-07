set -exou

pushd pyqt_sip

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
fi

if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    export ARCHFLAGS="-arch arm64"

    # Remove x86_64-specific flags and use arm64-compatible ones
    export CFLAGS=$(echo "${CFLAGS}" | sed -e 's/-march=core2//g' -e 's/-mtune=haswell//g' -e 's/-mssse3//g')
    export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e 's/-march=core2//g' -e 's/-mtune=haswell//g' -e 's/-mssse3//g')
fi

$PYTHON setup.py install

if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    # Verify the built library is arm64
    echo "Verifying sip extension architecture..."
    SIP_LIB=$(find $PREFIX/lib/python*/site-packages/PyQt6 -name "sip*.so" 2>/dev/null | head -n 1)
    if [[ -n "$SIP_LIB" ]]; then
        file "$SIP_LIB"
        if ! file "$SIP_LIB" | grep -q "arm64"; then
            echo "ERROR: sip library is not arm64!"
            exit 1
        fi
        echo "The sip extension is verified as arm64"
    fi
fi
