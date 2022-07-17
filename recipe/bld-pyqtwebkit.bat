:: install pyqtwebkit
md %SP_DIR%\PyQt5
md %SP_DIR%\PyQt5\bindings
move %TEMP%\pyqtwebkit\QtWebKit*.so %SP_DIR%\PyQt5\ 
xmove %TEMP%\pyqtwebkit\QtWebKit %SP_DIR%\PyQt5\bindings\
