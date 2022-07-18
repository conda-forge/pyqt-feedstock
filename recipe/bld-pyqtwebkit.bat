:: install pyqtwebkit
md %SP_DIR%\PyQt5
md %SP_DIR%\PyQt5\bindings
move %TEMP%\pyqtwebkit\QtWebKit* %SP_DIR%\PyQt5\ 
move %TEMP%\pyqtwebkit\QtWebKit %SP_DIR%\PyQt5\bindings\
