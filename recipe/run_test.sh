# For aarch64 only: Copy shared object files required for import tests.
if [[ ${target_platform} == linux-aarch64 ]]; then
    cp -n ${BUILD_PREFIX}/aarch64-conda-linux-gnu/sysroot/usr/lib64/*.so* ${PREFIX}/lib/
    cp -n ${BUILD_PREFIX}/aarch64-conda-linux-gnu/sysroot/lib64/libasound.so* ${PREFIX}/lib/
fi

# Test importing of modules.
python -c "from PyQt5 import \
    sip, \
    QtChart, \
    QtCore, \
    QtGui, \
    QtHelp, \
    QtMultimedia, \
    QtMultimediaWidgets, \
    QtNetwork, \
    QtOpenGL, \
    QtPrintSupport, \
    QtQml, \
    QtQuick, \
    QtSvg, \
    QtTest, \
    QtWebChannel, \
    QtWebEngine, \
    QtWebEngineCore, \
    QtWebEngineWidgets, \
    QtWebSockets, \
    QtWidgets, \
    QtXml, \
    QtXmlPatterns"
