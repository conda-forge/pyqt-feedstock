set -exou

## install pyqtwebkit
cp pyqtwebkit/QtWebKit*.so ${SP_DIR}/PyQt5/ 
cp -r pyqtwebkit/QtWebKit ${SP_DIR}/PyQt5/bindings/
