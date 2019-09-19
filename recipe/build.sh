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

# need to build a private copy of sip to avoid "module PyQt5.sip not found" error
echo -e "\n************** start building a private sip module **************"
echo "PWD: ${SRC_DIR}"
cd sip
$PYTHON configure.py --sip-module PyQt5.sip
make -j${CPU_COUNT} # ${VERBOSE_AT}
make install
cd ../
echo -e "*****************************************************************\n"

## create alias for libGL.so
#ln -s ${PREFIX}/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/libGL.so.1 \
#      ${PREFIX}/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/libGL.so

## START BUILD
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
        "${_extra_modules[@]}" \
        -q ${PREFIX}/bin/qmake

make -j${CPU_COUNT} ${VERBOSE_AT}
make check
make install

# install PyQtWebEngine
if [ "$PY_VER" == "3.5" ] || [ "$PY_VER" == "3.6" ] || [ "$PY_VER" == "3.7" ] || [ "$PY_VER" == "3.8" ]; then
    if [ `uname` == Darwin ]; then
        pip install --no-deps https://files.pythonhosted.org/packages/c8/7f/e16146569e881d588933641fe17f7d6a33a667b8ca1f6b7b231f8d11db33/PyQtWebEngine-5.12.1-5.12.4-cp35.cp36.cp37.cp38-abi3-macosx_10_6_intel.whl
    fi

    if [ `uname` == Linux ]; then
        pip install --no-deps https://files.pythonhosted.org/packages/da/fb/aa8344730c31174ffc81453da2d8ad2a626e618915529da5c73185ccca89/PyQtWebEngine-5.12.1-5.12.4-cp35.cp36.cp37.cp38-abi3-manylinux1_x86_64.whl
    fi
fi
