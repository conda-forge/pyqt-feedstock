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
    # Conda-forge uses prefixed compilers (e.g. x86_64-conda-linux-gnu-c++),
    # but qmake searches for bare "g++".  Create symlinks so qmake finds them.
    ln -sf "${GXX}" g++ 2>/dev/null || true
    ln -sf "${GCC}" gcc 2>/dev/null || true
    chmod +x g++ gcc 2>/dev/null || true
    export PATH="${PWD}:${PATH}"
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

# 8b — Fix -lpython to use HOST python version, not BUILD.
#      sip-build runs under BUILD python (e.g. 3.14), generating Makefiles
#      with -lpython3.14.  The plugin must link against HOST python 3.12.
#      PY_VER is a conda-build variable = "3.12" (major.minor) for HOST.
find . -name "Makefile" -exec sed -i.bak \
    's|-lpython[0-9]\.[0-9]*|-lpython'"${PY_VER}"'|g' {} +

# 8c — PYTHON_LIB: replace build env's library name with HOST python SONAME.
#      pyqt-builder (or our project.py patch) writes
#      -DPYTHON_LIB=\"libpython3.XY.so\" into the Makefile.
#      Replace with the correct HOST python SONAME.
find . -name "Makefile" -exec sed -i.bak \
    's|-DPYTHON_LIB=\\"libpython[0-9.]*\.so[0-9.]*\\"|-DPYTHON_LIB=\\"libpython'"${PY_VER}"'.so\\"|g' {} +
find . -name "*.bak" -delete

# 8d — Add -L$PREFIX/lib for -lGL resolution (Linux only).
#      On macOS Qt6 uses Metal/OpenGL.framework, not -lGL.
if [[ $(uname) == "Linux" ]]; then
    sed -i '/^LFLAGS/ s|$| -L'"${PREFIX}"'/lib|' designer/Makefile
    sed -i 's| -L  *\(-[lL]\)| -L'"${PREFIX}"'/lib \1|g' designer/Makefile
fi


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
mkdir -p "${PREFIX}/lib/qt6/plugins/designer"
cp libpyqt6.so "${PREFIX}/lib/qt6/plugins/designer/"


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
PYLIB=$(strings "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
    | grep -E '^libpython[0-9]+\.[0-9]+\.so(.[0-9]+)?$' || true)
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
if [[ "${build_platform}" == "${target_platform}" ]]; then
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
