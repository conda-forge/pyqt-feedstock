echo on

pushd pyqt
copy LICENSE ..

set PATH=%cd%\jom;%PATH%
set PATH=%LIBRARY_INC%;%PATH%

call sip-build ^
    --verbose ^
    --confirm-license ^
    --disable QtNfc ^
    --no-dbus-python ^
    --target-dir %SP_DIR% ^
    --no-make
if %ERRORLEVEL% neq 0 exit 1

pushd build

jom
if %ERRORLEVEL% neq 0 exit 1
jom install
if %ERRORLEVEL% neq 0 exit 1
