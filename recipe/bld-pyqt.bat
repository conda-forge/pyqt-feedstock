pushd pyqt
copy LICENSE ..

set PATH=%cd%\jom;%PATH%
set PATH=%LIBRARY_INC%;%PATH%

call sip-build ^
    --verbose ^
    --confirm-license ^
    --disable QtNfc ^
    --no-make
if %ERRORLEVEL% neq 0 exit 1

pushd build

jom
if %ERRORLEVEL% neq 0 exit 1
jom install
if %ERRORLEVEL% neq 0 exit 1

## remove qtwebkit stuff, this is packaged separately by bld_pyqtwebkit.bat
md  %TEMP%\pyqtwebkit
move %SP_DIR%\PyQt5\QtWebKit*.so %TEMP%\pyqtwebkit\
xmove %SP_DIR%\PyQt5\bindings\QtWebKit %TEMP%\pyqtwebkit\

