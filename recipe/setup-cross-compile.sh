#!/bin/bash
# Shared script to set up cross-compilation for PyQt6.
# This is sourced by all build-*.sh scripts.

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Get the recipe directory (where this script is located).
  RECIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ $(uname) == "Darwin" ]]; then
    # Force arm64 when cross-compiling macOS on x86_64 builders.
    cp "${RECIPE_DIR}/qmake-osx-arm64.conf" .qmake.conf
  fi

  # Point qmake at the target Qt installation for headers and libraries while
  # still using the build-platform host tools.
  sed -e "s|@PREFIX@|${PREFIX}|g" \
      -e "s|@BUILD_PREFIX@|${BUILD_PREFIX}|g" \
      "${RECIPE_DIR}/qt-target.conf.in" > qt-target.conf

  QMAKE_WRAPPER="${BUILD_PREFIX}/bin/qmake-target"

  sed "s|@QTCONF_PATH@|${PWD}/qt-target.conf|g" \
      "${RECIPE_DIR}/qmake-wrapper.sh.in" > "${QMAKE_WRAPPER}"

  chmod +x "${QMAKE_WRAPPER}"
  ln -sf "${QMAKE_WRAPPER}" "${BUILD_PREFIX}/bin/qmake"
fi
