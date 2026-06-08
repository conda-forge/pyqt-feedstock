set -exou

pushd pyqt
cp LICENSE ..

SIP_COMMAND="sip-build"
EXTRA_FLAGS=""

if [[ $(uname) == "Linux" ]]; then
    USED_BUILD_PREFIX=${BUILD_PREFIX:-${PREFIX}}
    echo USED_BUILD_PREFIX=${BUILD_PREFIX}

    ln -s ${GXX} g++ || true
    ln -s ${GCC} gcc || true
    ln -s ${USED_BUILD_PREFIX}/bin/${HOST}-gcc-ar gcc-ar || true

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

    # QNativeInterface X11/Wayland bindings are Linux-only and fail to compile on macOS.
    EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_XCB"
    EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_Wayland"
fi

# Set up cross-compilation (creates qmake wrapper and qt.conf)
source ${RECIPE_DIR}/setup-cross-compile.sh

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Vulkan bindings fail when the cross target QtGui headers do not expose the
  # QVulkan* API expected by the generated SIP sources.
  EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_Vulkan"
  # OpenGL ES2 detection is unreliable when probing the target Qt during cross
  # builds and can leave generated QtOpenGL sources referencing missing ES2
  # types on arm64 targets.
  EXTRA_FLAGS="${EXTRA_FLAGS} --disabled-feature=PyQt_OpenGL_ES2"
  SIP_COMMAND="$BUILD_PREFIX/bin/python -m sipbuild.tools.build"
  SITE_PKGS_PATH=$($PREFIX/bin/python -c 'import site;print(site.getsitepackages()[0])')
  EXTRA_FLAGS="${EXTRA_FLAGS} --target-dir $SITE_PKGS_PATH"
else
  ln -s ${PREFIX}/bin/qmake6 ${PREFIX}/bin/qmake
fi

$SIP_COMMAND \
--verbose \
--confirm-license \
--no-make \
$EXTRA_FLAGS

pushd build

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Make sure BUILD_PREFIX sip-distinfo is called instead of the HOST one
  cat Makefile | sed -r 's|\t(.*)sip-distinfo(.*)|\t'$BUILD_PREFIX/bin/python' -m sipbuild.tools.distinfo \2|' > Makefile.temp
  rm Makefile
  mv Makefile.temp Makefile
fi

CPATH=$PREFIX/include make -j$CPU_COUNT
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
# On macOS the Makefile target is libpyqt6.dylib; on Linux it is libpyqt6.so.
# Qt plugins always use .so extension even on macOS.
if [[ -f libpyqt6.dylib ]]; then
    PLUGIN_FILE="libpyqt6.dylib"
else
    PLUGIN_FILE="libpyqt6.so"
fi
mkdir -p "${PREFIX}/lib/qt6/plugins/designer"
cp "${PLUGIN_FILE}" "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so"

if [[ $(uname) == "Linux" ]]; then
    patchelf --remove-rpath "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so"
fi
if [[ $(uname) == "Darwin" ]]; then
    for rpath in $(otool -l "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
        | grep -A2 "LC_RPATH" | grep "path " | awk '{print $2}'); do
        install_name_tool -delete_rpath "${rpath}" \
            "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" 2>/dev/null || true
    done
    # Fix LC_ID_DYLIB to match the renamed file, otherwise conda-build's
    # delocate step looks for libpyqt6.dylib on macOS.
    install_name_tool -id "@rpath/libpyqt6.so" \
        "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so"
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
