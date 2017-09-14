#!/bin/bash

set -e # Abort on error.

# Avoid Xcode, cannot put in ${SRC_DIR} as there is a dir called 'sip'
# there which shadows the sip excutable.
mkdir xcode
pushd xcode
  cp "${RECIPE_DIR}"/xcrun .
  cp "${RECIPE_DIR}"/xcodebuild .
  PATH=${PWD}:${PATH}
popd

if [[ 0 == 1 ]]; then
export PING_SLEEP=30s
export WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BUILD_OUTPUT=$WORKDIR/build.out

touch $BUILD_OUTPUT

dump_output() {
   echo Tailing the last 500 lines of output:
   tail -500 $BUILD_OUTPUT
}
error_handler() {
  echo ERROR: An error was encountered with the build.
  dump_output
  kill $PING_LOOP_PID
  exit 1
}

# If an error occurs, run our error handler to output a tail of the build.
trap 'error_handler' ERR

# Set up a repeating loop to send some output to Travis.
bash -c "while true; do echo \$(date) - building ...; sleep $PING_SLEEP; done" &
PING_LOOP_PID=$!
fi

# Dumb .. is this Qt or PyQt's fault? (or mine, more likely).
# The spec file could be bad, or PyQt could be missing the
# ability to set QMAKE_CXX
mkdir bin
pushd bin
  ln -s ${GXX} g++
  ln -s ${GCC} gcc
popd
export PATH=${PWD}/bin:${PATH}

## START BUILD
$PYTHON configure.py \
        --verbose \
        --confirm-license \
        --assume-shared \
        -q ${PREFIX}/bin/qmake
make -j${CPU_COUNT} ${VERBOSE_AT} # >> $BUILD_OUTPUT 2>&1
make check # >> $BUILD_OUTPUT 2>&1
make install # >> $BUILD_OUTPUT 2>&1

if [[ 0 == 1 ]]; then
## END BUILD

# The build finished without returning an error so dump a tail of the output.
dump_output

# Nicely terminate the ping output loop.
kill $PING_LOOP_PID
fi
