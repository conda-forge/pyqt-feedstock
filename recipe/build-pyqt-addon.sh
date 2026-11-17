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

SIP_COMMAND="sip-build"
# Keep feature flags identical to build-pyqt.sh so the generated code matches
# the modules shipped in pyqt6.
EXTRA_FLAGS=""

if [[ $(uname) == "Linux" ]]; then
    # Resolve the activated toolchain before replacing any compiler shims.
    GXX_PATH=$(command -v "${GXX}")
    GCC_PATH=$(command -v "${GCC}")
    GCC_AR_PATH=$(command -v "${GCC_AR}")
    ln -sf "${GXX_PATH}" g++
    ln -sf "${GCC_PATH}" gcc
    ln -sf "${GCC_AR_PATH}" gcc-ar

    export LD=${GXX}
    export CC=${GCC}
    export CXX=${GXX}
    export PKG_CONFIG_EXECUTABLE=$(basename $(which pkg-config))

    chmod +x g++ gcc gcc-ar
    export PATH=${PWD}:${PATH}

    SYSROOT_FLAGS="-L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib"
    export CFLAGS="$SYSROOT_FLAGS $CFLAGS"
    export CXXFLAGS="$SYSROOT_FLAGS $CXXFLAGS"
    export LDFLAGS="$SYSROOT_FLAGS $LDFLAGS"
fi

if [[ $(uname) == "Darwin" ]]; then
    # Use xcode-avoidance scripts
    export PATH=$PREFIX/bin/xc-avoidance:$PATH

    EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_XCB"
    EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_Wayland"
fi

# Set up cross-compilation (creates qmake wrapper and qt.conf)
source ${RECIPE_DIR}/setup-cross-compile.sh

# Only create the qmake symlink if it isn't already present, and remove it
# afterwards so it doesn't end up in this package.
CREATED_QMAKE=0
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_OpenGL_ES2"
  SIP_COMMAND="$BUILD_PREFIX/bin/python -m sipbuild.tools.build"
  BUILD_PYTHON="${BUILD_PREFIX}/bin/python"
else
  BUILD_PYTHON="${PYTHON}"
  if [[ ! -e "${PREFIX}/bin/qmake" ]]; then
    ln -s ${PREFIX}/bin/qmake6 ${PREFIX}/bin/qmake
    CREATED_QMAKE=1
  fi
fi

export CPATH="${PREFIX}/include${CPATH:+:${CPATH}}"

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
$EXTRA_FLAGS

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
