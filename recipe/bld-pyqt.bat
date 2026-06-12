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

call sip-build --verbose --qt-shared --no-make --confirm-license
if %ERRORLEVEL% neq 0 exit 1

if not exist build\designer (
    echo ERROR: build\designer directory not found after sip-build --qt-shared
    dir /b build 2^>nul
    exit 1
)
cd build\designer
REM Debug: list generated files
dir /b
jom
if %ERRORLEVEL% neq 0 exit 1
REM Debug: list built files
dir /b

REM MSVC qmake places the plugin DLL in a release\ subdirectory
set "PLUGIN_FILE="
for /r %%f in (*.dll) do if not defined PLUGIN_FILE set "PLUGIN_FILE=%%f"
if not defined PLUGIN_FILE (
    echo ERROR: No plugin DLL found in build\designer
    dir /s /b 2^>nul
    exit 1
)

if not exist "%PREFIX%\Library\plugins\designer" mkdir "%PREFIX%\Library\plugins\designer"
copy /Y "%PLUGIN_FILE%" "%PREFIX%\Library\plugins\designer\libpyqt6.dll"
if %ERRORLEVEL% neq 0 exit 1
