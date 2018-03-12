#!/bin/bash

set -e # Abort on error.

# Avoid Xcode
if [[ ${HOST} =~ .*darwin.* ]]; then
  PATH=${PREFIX}/bin/xc-avoidance:${PATH}
fi

# Dumb .. is this Qt or PyQt's fault? (or mine, more likely).
# The spec file could be bad, or PyQt could be missing the
# ability to set QMAKE_CXX
mkdir bin
pushd bin
  ln -s ${GXX} g++
  ln -s ${GCC} gcc
popd
export PATH=${PWD}/bin:${PATH}

## START BUILD
$PYTHON configure.py \
        --verbose \
        --confirm-license \
        --assume-shared \
        -q ${PREFIX}/bin/qmake
make -j${CPU_COUNT} ${VERBOSE_AT}
make check
make install
