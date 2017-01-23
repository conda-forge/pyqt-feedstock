#!/bin/bash

$PYTHON configure.py \
        --verbose \
        --confirm-license \
        --assume-shared \
        -q $PREFIX/bin/qmake

make -j$CPU_COUNT
make check
make install
