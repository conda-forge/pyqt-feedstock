set -exou

# Builds the pyqt6 add-on outputs (pyqt6-multimedia, pyqt6-serialport,
# pyqt6-positioning). Their bindings live in the main PyQt6 sdist but are
# packaged separately so that pyqt6 doesn't pull in the extra Qt libraries.
# Only the output's own modules are compiled (in a separate build dir, into a
# staging dir) and only their files are installed, so nothing clashes with pyqt6.
pushd pyqt

case "${PKG_NAME}" in
    pyqt6-multimedia)
        ADDON_MODULES="QtMultimedia QtMultimediaWidgets"
        if [[ -d "${PREFIX}/include/qt6/QtSpatialAudio" ]]; then
            ADDON_MODULES="${ADDON_MODULES} QtSpatialAudio"
        fi
        ;;
    pyqt6-serialport)
        ADDON_MODULES="QtSerialPort"
        ;;
    pyqt6-positioning)
        ADDON_MODULES="QtPositioning"
        ;;
    *)
        echo "ERROR: unknown add-on output ${PKG_NAME}"
        exit 1
        ;;
esac

# Toolchain, cross-compilation and feature flags shared with build-pyqt.sh, so
# the generated code matches the modules shipped in pyqt6. If it creates the
# qmake symlink, it's removed below so it doesn't end up in this package.
source ${RECIPE_DIR}/setup-pyqt-build.sh

STAGE_DIR="${SRC_DIR}/${PKG_NAME}-stage"
BUILD_DIR="build-${PKG_NAME}"
rm -rf "${STAGE_DIR}" "${BUILD_DIR}"

# PyQt's project.py requires QtCore, and the modules the add-on bindings import
# must be configured (configuration tests, tags) the same way as in pyqt6.
# They are configured here but never compiled or installed. QtWebChannel is
# kept so that PyQt_WebChannel is decided the same way as in pyqt6.
# Everything else is disabled (not --enable, which skips the configuration tests).
DEP_MODULES="QtCore QtGui QtNetwork QtWidgets QtWebChannel"
DISABLE_FLAGS=$("${BUILD_PYTHON}" "${RECIPE_DIR}/pyqt_disable_flags.py" project.py ${DEP_MODULES} ${ADDON_MODULES})

$SIP_COMMAND \
--verbose \
--confirm-license \
--no-make \
--no-tools \
--no-designer-plugin \
--no-qml-plugin \
--no-dbus-python \
--build-dir "${BUILD_DIR}" \
--target-dir "${STAGE_DIR}" \
${DISABLE_FLAGS} \
$PYQT_FEATURE_FLAGS

# Compile and install only the add-on modules. Each module's own Makefile
# installs its extension module, .sip files and .toml into the staging dir.
for m in ${ADDON_MODULES}; do
    if [[ ! -f "${BUILD_DIR}/${m}/Makefile" ]]; then
        echo "ERROR: ${m} failed its configuration test and was not generated"
        exit 1
    fi
    make -C "${BUILD_DIR}/${m}" -j$CPU_COUNT
    make -C "${BUILD_DIR}/${m}" install
done

"${BUILD_PYTHON}" "${RECIPE_DIR}/check_addon_toml.py" \
    sip "${STAGE_DIR}/PyQt6/bindings" "${SP_DIR}/PyQt6/bindings" ${ADDON_MODULES}

if [[ "${CREATED_QMAKE}" == "1" ]]; then
  rm -f "${PREFIX}/bin/qmake"
fi

# Install only the add-on modules and their .sip/.toml bindings.
mkdir -p "${SP_DIR}/PyQt6/bindings"
for m in ${ADDON_MODULES}; do
    found=0
    for f in "${STAGE_DIR}/PyQt6/${m}".*; do
        [[ -e "$f" ]] || continue
        cp -a "$f" "${SP_DIR}/PyQt6/"
        found=1
    done
    if [[ "${found}" != "1" ]]; then
        echo "ERROR: ${m} was not built"
        exit 1
    fi
    cp -a "${STAGE_DIR}/PyQt6/bindings/${m}" "${SP_DIR}/PyQt6/bindings/"
done

if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    echo "Verifying ${PKG_NAME} extension architectures..."
    for m in ${ADDON_MODULES}; do
        for lib in "${SP_DIR}/PyQt6/${m}".*so; do
            if ! file "$lib" | grep -q "arm64"; then
                echo "ERROR: $lib is not arm64!"
                file "$lib"
                exit 1
            fi
        done
    done
    echo "All ${PKG_NAME} extensions verified as arm64"
fi
