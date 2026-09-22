set -exou

pushd pyqt_charts

SIP_COMMAND="sip-build"
EXTRA_FLAGS=""

if [[ $(uname) == "Linux" ]]; then
    USED_BUILD_PREFIX=${BUILD_PREFIX:-${PREFIX}}
    echo USED_BUILD_PREFIX=${BUILD_PREFIX}

    ln -s $(which ${GXX}) g++ || true
    ln -s $(which ${GCC}) gcc || true
    ln -s ${USED_BUILD_PREFIX}/bin/${HOST}-gcc-ar gcc-ar || true

    export LD=${GXX}
    export CC=${GCC}
    export CXX=${GXX}
    export PKG_CONFIG_EXECUTABLE=$(basename $(which pkg-config))

    chmod +x g++ gcc gcc-ar
    export PATH=${PWD}:${PATH}
fi

if [[ $(uname) == "Darwin" ]]; then
    # Use xcode-avoidance scripts
    export PATH=$PREFIX/bin/xc-avoidance:$PATH
fi

export CONDA_BUILD_CROSS_COMPILATION=${CONDA_BUILD_CROSS_COMPILATION:-0}

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" == "1" ]]; then
  SIP_COMMAND="$BUILD_PREFIX/bin/python -m sipbuild.tools.build"
  SITE_PKGS_PATH=$($PREFIX/bin/python -c 'import site;print(site.getsitepackages()[0])')
  EXTRA_FLAGS="--target-dir $SITE_PKGS_PATH"

  # Build the path directly instead of `import PyQt5` and inspecting
  # __file__: the host python's sys.path can still resolve to an unrelated
  # PyQt5 (e.g. one left over in _build_env/venv) via an inherited
  # PYTHONPATH, which points sip-include-dirs at a mismatched-ABI copy.
  PYQT5_LOCATION="$SITE_PKGS_PATH/PyQt5/bindings"
  awk 'NR==25{$0="sip-include-dirs = [\"'$PYQT5_LOCATION'\"]\n"}1' pyproject.toml >  pyproject.toml.tmp
  rm pyproject.toml
  mv pyproject.toml.tmp pyproject.toml
fi

$SIP_COMMAND \
--verbose \
--no-make \
$EXTRA_FLAGS

pushd build
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Make sure BUILD_PREFIX sip-distinfo is called instead of the HOST one
  cat Makefile | sed -r 's|\t(.*)sip-distinfo(.*)|\t'$BUILD_PREFIX/bin/python' -m sipbuild.tools.distinfo \2|' > Makefile.temp
  rm Makefile
  mv Makefile.temp Makefile

  # # For some reason SIP does not add the QtPrintSupport headers
  # cat QtWebEngineWidgets/Makefile | sed -r 's|INCPATH       =(.*)|INCPATH       =\1 -I'$PREFIX/include/qt/QtPrintSupport'|' > QtWebEngineWidgets/Makefile.temp
  # rm QtWebEngineWidgets/Makefile
  # mv QtWebEngineWidgets/Makefile.temp QtWebEngineWidgets/Makefile
fi

CPATH=$PREFIX/include make -j$CPU_COUNT
make install
