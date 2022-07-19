set -exou

## install pyqtwebkit
mkdir -p ${SP_DIR}/PyQt5/bindings
mv /tmp/pyqtwebkit/QtWebKit ${SP_DIR}/PyQt5/bindings/
mv /tmp/pyqtwebkit/QtWebKit* ${SP_DIR}/PyQt5/ 
