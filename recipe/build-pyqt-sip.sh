#!/bin/bash

set -e # Abort on error.

declare -a _extra_modules
# Avoid Xcode
if [[ ${HOST} =~ .*darwin.* ]]; then
  PATH=${PREFIX}/bin/xc-avoidance:${PATH}
    _extra_modules+=(--enable)
    _extra_modules+=(QtMacExtras)
else
    _extra_modules+=(--enable)
    _extra_modules+=(QtX11Extras)
fi


# Dumb .. is this Qt or PyQt's fault? (or mine, more likely).
# The spec file could be bad, or PyQt could be missing the
# ability to set QMAKE_CXX
mkdir -p bin
if [[ "${target_platform}" == linux-* ]]; then
  pushd bin
    ln -s $(which ${STRIP}) strip || true
    ln -s $(which ${GXX}) g++ || true
    ln -s $(which ${GCC}) gcc || true
  popd
fi
export PATH=${PWD}/bin:${PATH}

## Future:
#        --enable Qt3DAnimation \
#        --enable Qt3DCore \
#        --enable Qt3DExtras \
#        --enable Qt3DInput \
#        --enable Qt3DLogic \
#        --enable Qt3DRender \

# need to build a private copy of sip to avoid "module PyQt5.sip not found" error
echo -e "\n************** start building a private sip module **************\n"
#echo "PWD: ${SRC_DIR}"
cd sip
$PYTHON configure.py --sip-module PyQt5.sip
make -j${CPU_COUNT} # ${VERBOSE_AT}
make install
cd ../
echo -e "\n************************ built sip module ***********************\n"
