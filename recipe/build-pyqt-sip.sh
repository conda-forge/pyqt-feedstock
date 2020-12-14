#!/bin/bash

# Avoid Xcode
if [[ ${HOST} =~ .*darwin.* ]]; then
  PATH=${PREFIX}/bin/xc-avoidance:${PATH}
fi


# Dumb .. is this Qt or PyQt's fault? (or mine, more likely).
# The spec file could be bad, or PyQt could be missing the
# ability to set QMAKE_CXX
mkdir bin || true
pushd bin
  ln -s ${GXX} g++ || true
  ln -s ${GCC} gcc || true
popd
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
export LINK=${CC}
$PYTHON configure.py --sip-module PyQt5.sip --sysroot=${PREFIX}
make -j${CPU_COUNT} # ${VERBOSE_AT}
make install
cd ../
echo -e "\n************************ built sip module ***********************\n"
