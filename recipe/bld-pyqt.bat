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

REM Undo configure.py modification to __init__.py that does os.add_dll_directory()
REM for the first directory on the user's PATH that includes Qt5Core.dll, which
REM conda-forge does not distribute. This just copies the original __init__.py
REM from the source so that it does not have the modification.
REM See https://github.com/conda-forge/pyqt-feedstock/issues/138
copy /y "__init__.py" "%SP_DIR%\PyQt5\__init__.py"
