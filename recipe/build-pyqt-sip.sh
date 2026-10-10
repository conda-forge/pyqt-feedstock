set -exou

pushd pyqt_sip

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
