set -exou

cd $SRC_DIR

pushd pyqt_sip
$PYTHON -m pip install . -vv --no-deps --no-build-isolation
