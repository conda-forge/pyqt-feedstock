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

## START BUILD
$PYTHON configure.py \
        --verbose \
        --confirm-license \
        --assume-shared \
        --enable QtWidgets \
        --enable QtGui \
        --enable QtCore \
        --enable QtHelp \
        --enable QtMultimediaWidgets \
        --enable QtNetwork \
        --enable QtXml \
        --enable QtXmlPatterns \
        --enable QtDBus \
        --enable QtX11Extras \
        --enable QtWebSockets \
        --enable QtWebChannel \
        --enable QtWebEngineWidgets \
        --enable QtNfc \
        --enable QtWebEngineCore \
        --enable QtWebEngine \
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
        "${_extra_modules[@]}" \
        -q ${PREFIX}/bin/qmake
make -j${CPU_COUNT} ${VERBOSE_AT}
make check
make install
