pushd pyqt_webengine

set PATH=%cd%\jom;%PATH%
set PATH=%LIBRARY_INC%;%PATH%

call sip-build ^
     --verbose ^
     --no-make
if %ERRORLEVEL% neq 0 exit 1

pushd build

jom
if %ERRORLEVEL% neq 0 exit 1
jom install
if %ERRORLEVEL% neq 0 exit 1

python "%RECIPE_DIR%\fix_dist_info_record.py" PyQt6-WebEngine
if %ERRORLEVEL% neq 0 exit 1
