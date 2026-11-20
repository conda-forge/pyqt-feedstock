set -exou

pushd pyqt
cp LICENSE ..

# Toolchain, cross-compilation and feature flags shared with build-pyqt-addon.sh
source ${RECIPE_DIR}/setup-pyqt-build.sh

# These bindings are shipped separately in the pyqt6-multimedia,
# pyqt6-serialport and pyqt6-positioning outputs (build-pyqt-addon.sh).
EXTRA_FLAGS="--disable QtMultimedia --disable QtMultimediaWidgets --disable QtSpatialAudio"
EXTRA_FLAGS="${EXTRA_FLAGS} --disable QtSerialPort --disable QtPositioning"

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  SITE_PKGS_PATH=$($PREFIX/bin/python -c 'import site;print(site.getsitepackages()[0])')
  EXTRA_FLAGS="${EXTRA_FLAGS} --target-dir $SITE_PKGS_PATH"
fi

$SIP_COMMAND \
--verbose \
--confirm-license \
--no-make \
$PYQT_FEATURE_FLAGS \
$EXTRA_FLAGS

pushd build

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Make sure BUILD_PREFIX sip-distinfo is called instead of the HOST one
  cat Makefile | sed -r 's|\t(.*)sip-distinfo(.*)|\t'$BUILD_PREFIX/bin/python' -m sipbuild.tools.distinfo \2|' > Makefile.temp
  rm Makefile
  mv Makefile.temp Makefile
fi

make -j$CPU_COUNT
make install

# ---- Build and install the Qt Designer plugin -------------------------
popd  # pyqt/build/ → pyqt/
python "${RECIPE_DIR}/patch_py_pylib_shlib.py" project.py

sip-build \
    --verbose \
    --qt-shared \
    --no-make \
    --confirm-license

cd build/designer
# Fix empty -L flags in generated Makefile (qmake sometimes emits
# -L without a path before -lpython or -lGL)
sed -i.bak \
    -e '/^LFLAGS/ s|$| -L'"${PREFIX}"'/lib|' \
    -e 's| -L  *\(-[lL]\)| -L'"${PREFIX}"'/lib \1|g' \
    Makefile
rm -f Makefile.bak
CPATH="${PREFIX}/include" make -j"${CPU_COUNT}"
SHLIB_EXT=""
for ext in .dylib .so; do
    if [[ -f "libpyqt6${ext}" ]]; then
        SHLIB_EXT="${ext}"
        break
    fi
done
if [[ -z "${SHLIB_EXT}" ]]; then
    echo "ERROR: libpyqt6 plugin not found after build (tried .dylib, .so)"
    exit 1
fi
mkdir -p "${PREFIX}/lib/qt6/plugins/designer"
cp "libpyqt6${SHLIB_EXT}" "${PREFIX}/lib/qt6/plugins/designer/libpyqt6${SHLIB_EXT}"

if [[ $(uname) == "Linux" ]]; then
    patchelf --remove-rpath "${PREFIX}/lib/qt6/plugins/designer/libpyqt6${SHLIB_EXT}"
fi
if [[ $(uname) == "Darwin" ]]; then
    for rpath in $(otool -l "${PREFIX}/lib/qt6/plugins/designer/libpyqt6${SHLIB_EXT}" \
        | grep -A2 "LC_RPATH" | grep "path " | awk '{print $2}'); do
        install_name_tool -delete_rpath "${rpath}" \
            "${PREFIX}/lib/qt6/plugins/designer/libpyqt6${SHLIB_EXT}" 2>/dev/null || true
    done
    install_name_tool -id "@rpath/libpyqt6${SHLIB_EXT}" \
        "${PREFIX}/lib/qt6/plugins/designer/libpyqt6${SHLIB_EXT}"
fi
cd ../..  # pyqt/build/designer/ → pyqt/

if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    # Verify the built libraries are arm64
    echo "Verifying PyQt6 extension architectures..."
    for lib in $(find $PREFIX/lib/python*/site-packages/PyQt6 -name "*.so" 2>/dev/null); do
        if ! file "$lib" | grep -q "arm64"; then
            echo "ERROR: $lib is not arm64!"
            file "$lib"
            exit 1
        fi
    done
    echo "All PyQt6 extensions verified as arm64"
fi
