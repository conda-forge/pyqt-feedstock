set -exou

## install pyqtwebkit
mkdir -p ${SP_DIR}/PyQt5/bindings
cp /tmp/pyqtwebkit/QtWebKit*.so ${SP_DIR}/PyQt5/ 
cp -r /tmp/pyqtwebkit/QtWebKit ${SP_DIR}/PyQt5/bindings/
