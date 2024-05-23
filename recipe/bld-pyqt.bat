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

REM Undo configure.py modification to __init__.py that does os.add_dll_directory()
REM for the first directory on the user's PATH that includes Qt6Core.dll, which
REM could find an external DLL not from conda-forge. This just copies the original
REM  __init__.py from the source so that it does not have the modification.
REM See https://github.com/conda-forge/pyqt-feedstock/issues/138
copy /y "__init__.py" "%SP_DIR%\PyQt6\__init__.py"
