#!/bin/bash
# Shared script to set up macOS cross-compilation for PyQt6
# This is sourced by all build-*.sh scripts

if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Get the recipe directory (where this script is located)
  RECIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Copy static qmake.conf to force arm64 architecture
  cp "${RECIPE_DIR}/qmake-osx-arm64.conf" .qmake.conf

  # Create qt.conf from template that points to target Qt (arm64) for libraries/headers
  # but uses build Qt (x86_64) for host tools
  sed -e "s|@PREFIX@|${PREFIX}|g" \
      -e "s|@BUILD_PREFIX@|${BUILD_PREFIX}|g" \
      "${RECIPE_DIR}/qt-target.conf.in" > qt-target.conf

  QMAKE_WRAPPER="${BUILD_PREFIX}/bin/qmake-target"

  # Create qmake wrapper from template that uses target Qt configuration
  sed "s|@QTCONF_PATH@|${PWD}/qt-target.conf|g" \
      "${RECIPE_DIR}/qmake-wrapper.sh.in" > "${QMAKE_WRAPPER}"

  chmod +x ${QMAKE_WRAPPER}
  ln -sf ${QMAKE_WRAPPER} ${BUILD_PREFIX}/bin/qmake
fi
