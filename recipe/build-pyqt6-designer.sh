#!/bin/bash
set -exou

# ---------------------------------------------------------------------------
# Build the PyQt6 Qt Designer plugin (libpyqt6.so) from source sdist
#
# Conda-forge's pyqt6 package does NOT ship the Designer plugin because
# conda-forge Python is built without --enable-shared.  PyQt-builder then
# skips the plugin entirely.
#
# This script builds ONLY the plugin (not the full PyQt6) using 5 fixes
# that together produce a fully portable .so with zero absolute build paths.
#
# Fix strategy (see each step for details):
#   1. qmake env vars    → RPATH suppression, --no-as-needed
#   2. Targeted sed (3)  → PYTHON_LIB SONAME, -lpython version, -L$PREFIX/lib for -lGL
# ---------------------------------------------------------------------------

pushd pyqt6
cp LICENSE "${SRC_DIR}/"


# ---------------------------------------------------------------------------
# STEP 2 — Configure qmake via environment variables
# ---------------------------------------------------------------------------
# QMAKE_LFLAGS_RPATH= : empty value → qmake omits -Wl,-rpath,... entirely
# LD_RUN_PATH unset    : ld reads LD_RUN_PATH and adds DT_RUNPATH to every
#                        linked .so. conda-build sets this to $PREFIX/lib.
export QMAKE_LFLAGS_RPATH=
unset LD_RUN_PATH


# ---------------------------------------------------------------------------
# STEP 3 — Symlink qmake6 -> qmake
# ---------------------------------------------------------------------------
# Qt6 ships qmake6; sip-build expects plain qmake.
# Always create the symlink (even if the system has Qt5's /usr/bin/qmake)
# to ensure the Qt6 qmake is used.
if command -v qmake6 &>/dev/null; then
    ln -sf "$(command -v qmake6)" "${PREFIX}/bin/qmake"
fi


# ---------------------------------------------------------------------------
# STEP 4 — Patch project.py for conda-forge Python (no --enable-shared)
# ---------------------------------------------------------------------------
cp "${RECIPE_DIR}/patch_py_pylib_shlib.py" .
python patch_py_pylib_shlib.py project.py

# ---------------------------------------------------------------------------
# STEP 5 — Generate Makefiles with sip-build
# ---------------------------------------------------------------------------
# --qt-shared         : force plugin generation (otherwise skipped when
#                       Python is built --disable-shared)
# --no-make           : generate only; we fix Makefiles before compiling
sip-build \
    --verbose \
    --qt-shared \
    --no-make \
    --confirm-license \
    --qmake-setting "QMAKE_LFLAGS += -Wl,--no-as-needed"


# ---------------------------------------------------------------------------
# STEP 6 — Pre-build Makefile fixes (what qmake env vars can't handle)
# ---------------------------------------------------------------------------
cd build

# 6a — Remove any -Wl,-rpath from all Makefiles.
#      QMAKE_LFLAGS_RPATH= (STEP 2) prevents qmake from adding its own rpath,
#      but qmake may still inject -Wl,-rpath from .prl dependency files or
#      mkspecs.  Without this, an absolute build path ends up in DT_RUNPATH
#      and persists as dead string in .dynstr even after patchelf.
find . -name "Makefile" -exec sed -i \
    '-e s|-Wl,-rpath,[^ ]*||g' \
    '-e s|-Wl,-rpath-link,[^ ]*||g' {} +

# 6b — Fix -lpython to use HOST python version, not BUILD.
#      sip-build runs under BUILD python (e.g. 3.14), generating Makefiles
#      with -lpython3.14.  The plugin must link against HOST python 3.12.
#      PY_VER is a conda-build variable = "3.12" (major.minor) for HOST.
find . -name "Makefile" -exec sed -i \
    's|-lpython[0-9]\.[0-9]*|-lpython'"${PY_VER}"'|g' {} +

# 6c — PYTHON_LIB: replace build env's library name with HOST python SONAME.
#      pyqt-builder (or our project.py patch) writes
#      -DPYTHON_LIB=\"libpython3.XY.so\" or similar into the Makefile.
#      Replace with the correct HOST python SONAME (libpython3.11.so).
#      The \" delimiters in the Makefile require careful sed escaping:
#      we match the whole -DPYTHON_LIB=\"...\" and replace the value.
find . -name "Makefile" -exec sed -i \
    's|-DPYTHON_LIB=\\"libpython[0-9.]*\.so[0-9.]*\\"|-DPYTHON_LIB=\\"libpython'"${PY_VER}"'.so\\"|g' {} +

# 6d — Add -L$PREFIX/lib for -lGL resolution.
#      qmake strips environment LDFLAGS for the designer plugin target.
#      The BUILD prefix (libgl) only has libGL.so.1 (no .so symlink).
#      The HOST prefix (libgl-devel) has libGL.so.
#      Also fix bare "-L " (empty path from qmake's unset PREFIX variable).
sed -i '/^LFLAGS/ s|$| -L'"${PREFIX}"'/lib|' designer/Makefile
sed -i 's| -L  *\(-[lL]\)| -L'"${PREFIX}"'/lib \1|g' designer/Makefile


# ---------------------------------------------------------------------------
# STEP 6 — Compile (designer target only)
# ---------------------------------------------------------------------------
cd designer
CPATH="${PREFIX}/include" make -j"${CPU_COUNT}"


# ---------------------------------------------------------------------------
# STEP 7 — Manual install to host prefix (NOT make install)
# ---------------------------------------------------------------------------
# Conda-forge's qt.conf sets $$[QT_INSTALL_PLUGINS] to $BUILD_PREFIX/plugins
# (by design: it lets make install write to a prefix that conda-build packages).
# For the designer plugin target specifically, qmake's generated Makefile
# uses $$[QT_INSTALL_PLUGINS] directly as an absolute path, so even:
#     INSTALL_ROOT=$PREFIX make install
# produces $PREFIX/$BUILD_PREFIX/plugins — NOT $PREFIX/lib/qt6/plugins/.
# Manual cp is the simplest correct approach.
# Qt6 plugins go under lib/qt6/plugins/ (not plugins/ directly like Qt5).
mkdir -p "${PREFIX}/lib/qt6/plugins/designer"
cp libpyqt6.so "${PREFIX}/lib/qt6/plugins/designer/"


# ---------------------------------------------------------------------------
# STEP 8 — Remove any residual RPATH
# ---------------------------------------------------------------------------
# IMPORTANT: conda-build re-adds a relative RPATH ($ORIGIN/../../..) by default
# via build/rpaths: ["lib/"].  This overrides patchelf and embeds a relative
# RPATH in the final .so, which breaks Taurus Designer at runtime (it must use
# the calling process's RPATH, not $ORIGIN/...).
# SOLUTION: set 'rpaths: []' in the meta.yaml build section.
patchelf --remove-rpath "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so"


# ---------------------------------------------------------------------------
# STEP 9 — Verification
# ---------------------------------------------------------------------------

# 9a — RPATH must be empty
RPATH=$(patchelf --print-rpath "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so")
if [[ -n "${RPATH}" ]]; then
    echo "ERROR: RPATH still set: ${RPATH}"
    exit 1
fi
echo "RPATH check: PASS"

# 9b — PYTHON_LIB must be a simple SONAME (no absolute path)
PYLIB=$(strings "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
    | grep -E '^libpython[0-9]+\.[0-9]+\.so(.[0-9]+)?$' || true)
if echo "${PYLIB}" | grep -q '/'; then
    echo "ERROR: PYTHON_LIB contains an absolute path: ${PYLIB}"
    exit 1
fi
echo "PYTHON_LIB check: ${PYLIB}"

# 9c — Confirm Qt6Designer in DT_NEEDED (native builds only)
if [[ "${build_platform}" == "${target_platform}" ]]; then
    readelf -d "${PREFIX}/lib/qt6/plugins/designer/libpyqt6.so" \
        | grep -q "NEEDED.*Qt6Designer" \
        && echo "Qt6Designer NEEDED: PASS" \
        || echo "WARNING: Qt6Designer NOT in DT_NEEDED (may use lazy/python loading)"
fi


# ---------------------------------------------------------------------------
# STEP 10 — Cleanup: remove qmake symlink (would break packaging)
# ---------------------------------------------------------------------------
rm -f "${PREFIX}/bin/qmake"
