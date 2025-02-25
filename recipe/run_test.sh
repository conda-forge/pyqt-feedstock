#! /usr/bin/env bash

if [[ "${target_platform}" == linux-* ]]; then
  # Hack to help QtWebEngine find alsalib at module import time. We can't add ${BUILD_PREFIX}/${HOST}/sysroot/lib64 to
  # the LD_LIBRARY_PATH below because it causes segfaults in many system applications.
  ln -s ../../lib64/libasound.so.2 ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64/libasound.so.2

  # Add runtime path of libEGL.so.1 so Qt libraries can find it as they're loaded in.
  # This must be done before the python interpreter starts up.
  export LD_LIBRARY_PATH="${PREFIX}/${BUILD/conda_cos7/conda}/sysroot/usr/lib64:${LD_LIBRARY_PATH}"
fi

if [[ "${PKG_NAME}" == pyqt ]]; then
  ${PYTHON} ${RECIPE_DIR}/check_imports_pyqt.py

  test -f ${PREFIX}/bin/pyuic6 || (echo "FATAL: Failed to find pyuic6" && exit 1)

  # we don't have xvfb on our builders ... so we might ignore it ..
  DISPLAY=localhost:1.0 xvfb-run -a bash -c 'python pyqt_test.py' || true
  pyuic6 --version
else
  ${PYTHON} ${RECIPE_DIR}/check_imports_pyqtwebengine.py
fi
