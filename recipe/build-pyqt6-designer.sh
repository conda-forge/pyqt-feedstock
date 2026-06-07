#!/bin/bash
set -exou

# ---------------------------------------------------------------------------
# Build the PyQt6 Qt Designer plugin (libpyqt6.so) from source sdist
#
# Conda-forge's pyqt6 package does NOT ship the Designer plugin because
# conda-forge Python is built without --enable-shared.  PyQt-builder then
# skips the plugin entirely.
#
# This script builds ONLY the plugin (not the full PyQt6) using several
# fixes that together produce a fully portable .so with zero absolute
# build paths.
#
# Supports Linux (x86_64, aarch64) and macOS (x86_64, arm64).
# ---------------------------------------------------------------------------

trap 'rm -f "${PREFIX}/bin/qmake"' EXIT

pushd pyqt
cp LICENSE "${SRC_DIR}/"


# ---------------------------------------------------------------------------
# STEP 2 — Platform-specific setup
# ---------------------------------------------------------------------------

if [[ $(uname) == "Darwin" ]]; then
    # Use xcode-avoidance scripts (standard conda-forge pattern)
    export PATH="${PREFIX}/bin/xc-avoidance:${PATH}"

    # qmake searches for the C++ compiler by name; on macOS conda-forge
    # provides CC/CXX and clang is in PATH, so no symlinks needed.
fi

if [[ $(uname) == "Linux" ]]; then
    USED_BUILD_PREFIX=${BUILD_PREFIX:-${PREFIX}}

    # Conda-forge uses prefixed compilers (e.g. x86_64-conda-linux-gnu-c++),
    # but qmake searches for bare "g++".  Create symlinks so qmake finds them.
    ln -sf "${GXX}" g++ 2>/dev/null || true
    ln -sf "${GCC}" gcc 2>/dev/null || true
    ln -sf "${USED_BUILD_PREFIX}/bin/${HOST}-gcc-ar" gcc-ar 2>/dev/null || true
    chmod +x g++ gcc gcc-ar 2>/dev/null || true
    export PATH="${PWD}:${PATH}"

    # Export compilers explicitly so qmake uses the conda-forge toolchain.
    export LD="${GXX}"
    export CC="${GCC}"
    export CXX="${GXX}"

    # Strip path from pkg-config to avoid embedding BUILD_PREFIX in Makefiles.
    export PKG_CONFIG_EXECUTABLE=$(basename "$(which pkg-config)")

    # Sysroot library paths for cross-compilation (e.g. x86_64 -> aarch64).
    SYSROOT_FLAGS="-L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib"
    export CFLAGS="${SYSROOT_FLAGS} ${CFLAGS:-}"
    export CXXFLAGS="${SYSROOT_FLAGS} ${CXXFLAGS:-}"
    export LDFLAGS="${SYSROOT_FLAGS} ${LDFLAGS:-}"
fi


# ---------------------------------------------------------------------------
# STEP 3 — Configure qmake via environment variables
# ---------------------------------------------------------------------------
# QMAKE_LFLAGS_RPATH= : empty value → qmake omits -Wl,-rpath,... entirely
# LD_RUN_PATH unset    : ld reads LD_RUN_PATH and adds DT_RUNPATH to every
#                        linked .so. conda-build sets this to $PREFIX/lib.
export QMAKE_LFLAGS_RPATH=
unset LD_RUN_PATH


# ---------------------------------------------------------------------------
# STEP 4 — Symlink qmake6 -> qmake
# ---------------------------------------------------------------------------
# Qt6 ships qmake6; sip-build expects plain qmake.
# Always create the symlink (even if the system has Qt5's /usr/bin/qmake)
# to ensure the Qt6 qmake is used.
if command -v qmake6 &>/dev/null; then
    ln -sf "$(command -v qmake6)" "${PREFIX}/bin/qmake"
fi


# ---------------------------------------------------------------------------
# STEP 5 — Set up cross-compilation (qmake wrapper + target config)
# ---------------------------------------------------------------------------
source "${RECIPE_DIR}/setup-cross-compile.sh"
export CPATH="${PREFIX}/include:${CPATH:-}"


# ---------------------------------------------------------------------------
# STEP 6 — Patch project.py for conda-forge Python (no --enable-shared)
# ---------------------------------------------------------------------------
cp "${RECIPE_DIR}/patch_py_pylib_shlib.py" .
python patch_py_pylib_shlib.py project.py


# ---------------------------------------------------------------------------
# STEP 7 — Generate Makefiles with sip-build
# ---------------------------------------------------------------------------
# --qt-shared         : force plugin generation (otherwise skipped when
#                       Python is built --disable-shared)
# --no-make           : generate only; we fix Makefiles before compiling
# --no-as-needed      : Linux-only; macOS ld doesn't support this flag

if [[ $(uname) == "Linux" ]]; then
    sip-build \
        --verbose \
        --qt-shared \
        --no-make \
        --confirm-license \
        --qmake-setting "QMAKE_LFLAGS += -Wl,--no-as-needed"
else
    sip-build \
        --verbose \
        --qt-shared \
        --no-make \
        --confirm-license
fi


# ---------------------------------------------------------------------------
# STEP 8 — Pre-build Makefile fixes (what qmake env vars can't handle)
# ---------------------------------------------------------------------------
cd build

# 8a — Remove any -Wl,-rpath from all Makefiles.
#      QMAKE_LFLAGS_RPATH= (STEP 3) prevents qmake from adding its own rpath,
#      but qmake may still inject -Wl,-rpath from .prl dependency files or
#      mkspecs.
find . -name "Makefile" -exec sed -i.bak \
    '-e s|-Wl,-rpath,[^ ]*||g' \
    '-e s|-Wl,-rpath-link,[^ ]*||g' {} +

# 8b — Strip ABI suffix (e.g. 't') then normalise the python version in ALL
#      Makefile paths to the HOST PY_VER.  The Makefiles are generated by
#      qmake/sip-build running in the BUILD environment, where Python may
#      have a different version or a debug ABI suffix.  The HOST prefix
#      ($PREFIX) may not even have a matching Python installed — the build
#      environment's Python is used only for code generation; linking and
#      runtime use the HOST python.
find . -name "Makefile" -exec sed -i.bak \
    's|python[0-9]\.[0-9]*[a-z]*|python'"${PY_VER}"'|g' {} +

find . -name "*.bak" -delete

# 8c — Mirror HOST python headers into BUILD_PREFIX so that after 8b the
#      Makefiles' header prerequisites (e.g. .../pythonX.Y/Python.h) resolve.
#      Symlink each individual header; do NOT use a directory symlink because
#      we must be able to create empty placeholders for version-specific
#      headers without modifying the HOST prefix.
_PY_INCDIR="${BUILD_PREFIX}/include/python${PY_VER}"
mkdir -p "$_PY_INCDIR"
for hdr in "${PREFIX}/include/python${PY_VER}"/*.h; do
    if [[ -f "$hdr" ]]; then
        hdr_name=$(basename "$hdr")
        if [[ ! -f "$_PY_INCDIR/$hdr_name" ]]; then
            ln -sf "$hdr" "$_PY_INCDIR/$hdr_name"
        fi
    fi
done

# 8e — Create empty placeholder files for header dependencies listed in
#      Makefiles that exist in the BUILD python but not in the HOST python
#      (e.g. pytypedefs.h added in 3.11, pystats.h added in 3.12).  The
#      HOST python's Python.h does not include them, so an empty file
#      satisfies make's prerequisite check without affecting compilation.
_PY_INCDIR="${BUILD_PREFIX}/include/python${PY_VER}"
for hdr_name in $(find . -name "Makefile" -exec grep -oh '[^ ]*/include/python[^/]*/[^ ]*\.h' {} \; | sed 's|.*/||' | sort -u); do
    if [[ ! -f "${_PY_INCDIR}/${hdr_name}" ]]; then
        touch "${_PY_INCDIR}/${hdr_name}"
    fi
done

# 8d — Add -L$PREFIX/lib for -lGL (Linux) and -lpython (macOS) resolution.
#      On Linux, sip-build may emit -lGL without a -L path for libGL.so.
#      On macOS, sip-build emits -lpythonX.Y without a -L path for the
#      conda HOST python library ($PREFIX/lib/libpython*.dylib).
#      NOTE: -i.bak (not -i) for BSD sed compatibility on macOS.
sed -i.bak \
    -e '/^LFLAGS/ s|$| -L'"${PREFIX}"'/lib|' \
    -e 's| -L  *\(-[lL]\)| -L'"${PREFIX}"'/lib \1|g' \
    designer/Makefile
rm -f designer/Makefile.bak


# ---------------------------------------------------------------------------
# STEP 9 — Compile (designer target only)
# ---------------------------------------------------------------------------
cd designer
CPATH="${PREFIX}/include" make -j"${CPU_COUNT}"


# ---------------------------------------------------------------------------
# STEP 10 — Manual install to host prefix (NOT make install)
# ---------------------------------------------------------------------------
# Conda-forge's qt.conf sets $$[QT_INSTALL_PLUGINS] to $BUILD_PREFIX/plugins
# (by design: it lets make install write to a prefix that conda-build packages).
# For the designer plugin target specifically, qmake's generated Makefile
# uses $$[QT_INSTALL_PLUGINS] directly as an absolute path, so even:
#     INSTALL_ROOT=$PREFIX make install
# produces $PREFIX/$BUILD_PREFIX/plugins — NOT $PREFIX/lib/qt6/plugins/.
# Manual cp is the simplest correct approach.
# On macOS the Makefile target is libpyqt6.dylib; on Linux it is libpyqt6.so.
# Qt plugins always use .so extension even on macOS.
if [[ -f libpyqt6.dylib ]]; then
    PLUGIN_FILE="libpyqt6.dylib"
else
    PLUGIN_FILE="libpyqt6.so"
fi
mkdir -p "${PREFIX}/lib/qt6/plugins/designer"
cp "${PLUGIN_FILE}" "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so"


# ---------------------------------------------------------------------------
# STEP 11 — Remove any residual RPATH / LC_RPATH
# ---------------------------------------------------------------------------
# IMPORTANT: conda-build re-adds a relative RPATH ($ORIGIN/../../..) by default
# via build/rpaths: ["lib/"].  This overrides patchelf and embeds a relative
# RPATH in the final .so, which breaks Taurus Designer at runtime (it must use
# the calling process's RPATH, not $ORIGIN/...).
# SOLUTION: set 'rpaths: []' in the meta.yaml build section.
if [[ $(uname) == "Linux" ]]; then
    patchelf --remove-rpath "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so"
fi

# On macOS the .so has no LC_RPATH from qmake when QMAKE_LFLAGS_RPATH= is
# set, but conda-build may inject one during install.  Remove any leftover.
if [[ $(uname) == "Darwin" ]]; then
    # Collect all LC_RPATH entries and delete them
    for rpath in $(otool -l "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
        | grep -A2 "LC_RPATH" | grep "path " | awk '{print $2}'); do
        install_name_tool -delete_rpath "${rpath}" \
            "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" 2>/dev/null || true
    done
fi


# ---------------------------------------------------------------------------
# STEP 12 — Verification
# ---------------------------------------------------------------------------

# 12a — RPATH / LC_RPATH must be empty
if [[ $(uname) == "Linux" ]]; then
    RPATH=$(patchelf --print-rpath "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so")
    if [[ -n "${RPATH}" ]]; then
        echo "ERROR: RPATH still set: ${RPATH}"
        exit 1
    fi
    echo "RPATH check: PASS"
elif [[ $(uname) == "Darwin" ]]; then
    RPATH_COUNT=$(otool -l "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
        | grep -c "LC_RPATH" || true)
    if [[ "${RPATH_COUNT}" -gt 0 ]]; then
        echo "ERROR: ${RPATH_COUNT} LC_RPATH entries still present"
        otool -l "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
            | grep -A2 "LC_RPATH"
        exit 1
    fi
    echo "LC_RPATH check: PASS"
fi

# 12b — PYTHON_LIB must be a simple SONAME (no absolute path)
#      On macOS the library may be embedded as .dylib; on Linux it is .so.
PYLIB=$(strings "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
    | grep -E '^libpython[0-9]+\.[0-9]+\.(so|dylib)(.[0-9]+)?$' || true)
if echo "${PYLIB}" | grep -q '/'; then
    echo "ERROR: PYTHON_LIB contains an absolute path: ${PYLIB}"
    exit 1
fi
echo "PYTHON_LIB check: ${PYLIB}"

# 12c — Verify architecture on macOS cross-compile (must be arm64)
if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    if ! file "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" | grep -q "arm64"; then
        echo "ERROR: libpyqt6.so is not arm64!"
        file "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so"
        exit 1
    fi
    echo "Architecture check (arm64): PASS"
fi

# 12d — Confirm Qt6Designer in shared library dependencies (native builds only)
if [[ "${build_platform:-}" == "${target_platform:-}" ]]; then
    if [[ $(uname) == "Linux" ]]; then
        readelf -d "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
            | grep -q "NEEDED.*Qt6Designer" \
            && echo "Qt6Designer NEEDED: PASS" \
            || echo "WARNING: Qt6Designer NOT in DT_NEEDED"
    elif [[ $(uname) == "Darwin" ]]; then
        otool -L "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
            | grep -q "Qt6Designer" \
            && echo "Qt6Designer in deps: PASS" \
            || echo "WARNING: Qt6Designer NOT in shared libs"
    fi
fi


# ---------------------------------------------------------------------------
# STEP 13 — Cleanup: remove qmake symlink (would break packaging)
# ---------------------------------------------------------------------------
rm -f "${PREFIX}/bin/qmake"
