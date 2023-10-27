set -exou

pushd pyqt_charts

if [[ $(uname) == "Darwin" ]]; then
    # Use xcode-avoidance scripts
    export PATH=$PREFIX/bin/xc-avoidance:$PATH
fi

sip-build \
--verbose \
--no-make \
$EXTRA_FLAGS

pushd build

CPATH=$PREFIX/include make -j$CPU_COUNT
make install
