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

## create alias for libGL.so
#ln -s ${PREFIX}/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/libGL.so.1 \
#      ${PREFIX}/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/libGL.so

## START BUILD
echo -e "\n************** start building PyQt5 **************\n"
cd pyqt5
$PYTHON configure.py \
        --verbose \
        --confirm-license \
        --assume-shared \
        --enable QtWidgets \
        --enable QtGui \
        --enable QtCore \
        --enable QtHelp \
        --enable QtMultimedia \
        --enable QtMultimediaWidgets \
        --enable QtNetwork \
        --enable QtXml \
        --enable QtXmlPatterns \
        --enable QtDBus \
        --enable QtWebSockets \
        --enable QtWebChannel \
        --enable QtNfc \
        --enable QtOpenGL \
        --enable QtQml \
        --enable QtQuick \
        --enable QtQuickWidgets \
        --enable QtSql \
        --enable QtSvg \
        --enable QtDesigner \
        --enable QtPrintSupport \
        --enable QtSensors \
        --enable QtTest \
        --enable QtBluetooth \
        --enable QtLocation \
        --enable QtPositioning \
        --enable QtSerialPort \
        --pyuic5-interpreter=`which python` \
        "${_extra_modules[@]}" \
        -q ${PREFIX}/bin/qmake

make -j${CPU_COUNT} ${VERBOSE_AT}
make check
make install
cd ../
echo -e "\n******************* built PyQt5 ******************\n"
