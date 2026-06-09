pushd pyqt
copy LICENSE ..

copy %LIBRARY_BIN%\qmake6.exe %LIBRARY_BIN%\qmake.exe

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

REM ---- Build and install the Qt Designer plugin -------------------------
popd
REM Windows Python is always shared, so patch_py_pylib_shlib.py is not needed

sip-build --verbose --qt-shared --no-make --confirm-license
if %ERRORLEVEL% neq 0 exit 1

cd build\designer
jom
if %ERRORLEVEL% neq 0 exit 1

if not exist "%PREFIX%\Library\plugins\designer" mkdir "%PREFIX%\Library\plugins\designer"
for /f "delims=" %%f in ('dir /b *.dll 2^>nul') do copy /Y "%%f" "%PREFIX%\Library\plugins\designer\libpyqt6.dll"
if %ERRORLEVEL% neq 0 exit 1
