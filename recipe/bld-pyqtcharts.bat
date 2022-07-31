echo on

pushd pyqt_charts

set PATH=%cd%\jom;%PATH%
set PATH=%LIBRARY_INC%;%PATH%

set "PKG_CONFIG_PATH=%LIBRARY_LIB%\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig;%BUILD_PREFIX%\Library\lib\pkgconfig"

call sip-build ^
     --verbose ^
     --target-dir %SP_DIR% ^
     --no-make
if %ERRORLEVEL% neq 0 exit 1

pushd build

jom
if %ERRORLEVEL% neq 0 exit 1
jom install
if %ERRORLEVEL% neq 0 exit 1
