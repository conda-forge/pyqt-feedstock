@echo on
REM Builds the pyqt6 add-on outputs (pyqt6-multimedia, pyqt6-serialport,
REM pyqt6-positioning). Their bindings live in the main PyQt6 sdist but are
REM packaged separately so that pyqt6 doesn't pull in the extra Qt libraries.
REM Only the output's own modules are compiled (in a separate build dir, into a
REM staging dir) and only their files are installed, so nothing clashes with pyqt6.
pushd pyqt

set "ADDON_MODULES="
if "%PKG_NAME%"=="pyqt6-multimedia" (
    set "ADDON_MODULES=QtMultimedia QtMultimediaWidgets"
    if exist "%LIBRARY_INC%\qt6\QtSpatialAudio" set "ADDON_MODULES=QtMultimedia QtMultimediaWidgets QtSpatialAudio"
)
if "%PKG_NAME%"=="pyqt6-serialport" set "ADDON_MODULES=QtSerialPort"
if "%PKG_NAME%"=="pyqt6-positioning" set "ADDON_MODULES=QtPositioning"
if not defined ADDON_MODULES (
    echo ERROR: unknown add-on output %PKG_NAME%
    exit 1
)

REM PyQt's project.py requires QtCore, and the modules the add-on bindings
REM import must be configured (configuration tests, tags) the same way as in
REM pyqt6. They are configured here but never compiled or installed.
REM QtWebChannel is kept so that PyQt_WebChannel is decided the same way as in
REM pyqt6. Everything else is disabled (not --enable, which skips the
REM configuration tests).
set "DEP_MODULES=QtCore QtGui QtNetwork QtWidgets QtWebChannel"

REM The extra outer quotes are needed: for /f runs the command with cmd /c,
REM which strips the first and last quote of a line with several quoted paths.
set "DISABLE_FLAGS="
for /f "delims=" %%i in ('""%PYTHON%" "%RECIPE_DIR%\pyqt_disable_flags.py" project.py %DEP_MODULES% %ADDON_MODULES%"') do set "DISABLE_FLAGS=%%i"
if not defined DISABLE_FLAGS exit 1

REM Only create qmake.exe if it isn't already present, and remove it afterwards
REM so it doesn't end up in this package.
set "CREATED_QMAKE=0"
if not exist "%LIBRARY_BIN%\qmake.exe" (
    copy "%LIBRARY_BIN%\qmake6.exe" "%LIBRARY_BIN%\qmake.exe"
    set "CREATED_QMAKE=1"
)

set PATH=%cd%\jom;%PATH%
set PATH=%LIBRARY_INC%;%PATH%

set "STAGE_DIR=%SRC_DIR%\%PKG_NAME%-stage"
set "BUILD_DIR=build-%PKG_NAME%"
if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"

call sip-build ^
    --verbose ^
    --confirm-license ^
    --no-make ^
    --no-tools ^
    --no-designer-plugin ^
    --no-qml-plugin ^
    --no-dbus-python ^
    --build-dir "%BUILD_DIR%" ^
    --target-dir "%STAGE_DIR%" ^
    %DISABLE_FLAGS%
if %ERRORLEVEL% neq 0 exit 1

REM Compile and install only the add-on modules. Each module's own Makefile
REM installs its extension module, .sip files and .toml into the staging dir.
for %%m in (%ADDON_MODULES%) do (
    if not exist "%BUILD_DIR%\%%m\Makefile" (
        echo ERROR: %%m failed its configuration test and was not generated
        exit 1
    )
    pushd "%BUILD_DIR%\%%m"

    jom
    if errorlevel 1 exit 1

    jom install
    if errorlevel 1 exit 1

    popd
)

"%PYTHON%" "%RECIPE_DIR%\check_addon_toml.py" sip "%STAGE_DIR%\PyQt6\bindings" "%SP_DIR%\PyQt6\bindings" %ADDON_MODULES%
if errorlevel 1 exit 1

if "%CREATED_QMAKE%"=="1" del "%LIBRARY_BIN%\qmake.exe"

REM Install only the add-on modules and their .sip/.toml bindings.
if not exist "%SP_DIR%\PyQt6\bindings" mkdir "%SP_DIR%\PyQt6\bindings"
for %%m in (%ADDON_MODULES%) do (
    if not exist "%STAGE_DIR%\PyQt6\%%m.pyd" (
        echo ERROR: %%m was not built
        exit 1
    )

    copy /Y "%STAGE_DIR%\PyQt6\%%m.*" "%SP_DIR%\PyQt6\"
    if errorlevel 1 exit 1

    xcopy /E /I /Y "%STAGE_DIR%\PyQt6\bindings\%%m" "%SP_DIR%\PyQt6\bindings\%%m"
    if errorlevel 1 exit 1
)
