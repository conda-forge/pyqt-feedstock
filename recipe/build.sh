#!/bin/bash

# Dumb .. is this Qt or PyQt's fault? (or mine, more likely).
# The spec file could be bad, or PyQt could be missing the
# ability to set QMAKE_CXX
mkdir bin || true
pushd bin
  ln -s ${GXX} g++ || true
  ln -s ${GCC} gcc || true
popd
export PATH=${PWD}/bin:${PATH}


if [ $(uname) == Linux ]; then
    export QMAKESPEC="linux-g++"

    # Add qt.conf to the right place in $SRC_DIR so that
    # configure.py can run correctly
    cp $PREFIX/bin/qt.conf $SRC_DIR
elif [ $(uname) == Darwin ]; then
    export QMAKESPEC=unsupported/macx-clang-libc++
    export DYLD_FALLBACK_LIBRARY_PATH=$PREFIX/lib/

    # Add qt.conf to the right place in $SRC_DIR so that
    # configure.py can run correctly
    QTCONF_PLACE=$SRC_DIR/qtdirs.app/Contents/Resources
    mkdir -p $QTCONF_PLACE
    cp $PREFIX/bin/qt.conf $QTCONF_PLACE
fi

$PYTHON configure.py \
          --verbose \
          --confirm-license \
          --bindir=$PREFIX/bin \
          --destdir=$SP_DIR \
          --qmake=$PREFIX/bin/qmake

make
make install

rm -rf $SP_DIR/__pycache__
