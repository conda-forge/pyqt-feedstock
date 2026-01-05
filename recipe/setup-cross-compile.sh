#!/bin/bash
# Shared script to set up macOS cross-compilation for PyQt6
# This is sourced by all build-*.sh scripts

if [[ $(uname) == "Darwin" && "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Create .qmake.conf to force arm64 architecture
  cat > .qmake.conf << 'EOF'
QMAKE_APPLE_DEVICE_ARCHS = arm64
EOF

  # Create qt.conf that points to target Qt (arm64) for libraries/headers
  # but uses build Qt (x86_64) for host tools like moc, uic, etc.
  # qmake will use this via -qtconf option
  cat > qt-target.conf << EOF
[Paths]
Prefix = $PREFIX
Documentation = $PREFIX/share/doc/qt6
Headers = $PREFIX/include/qt6
Libraries = $PREFIX/lib
LibraryExecutables = $BUILD_PREFIX/lib/qt6
Binaries = $BUILD_PREFIX/lib/qt6/bin
Plugins = $PREFIX/lib/qt6/plugins
QmlImports = $PREFIX/lib/qt6/qml
ArchData = $PREFIX/lib/qt6
HostData = $BUILD_PREFIX/lib/qt6
Data = $PREFIX/share/qt6
Translations = $PREFIX/share/qt6/translations
Examples = $PREFIX/share/doc/qt6/examples
Tests = $PREFIX/tests
HostLibraries = $BUILD_PREFIX/lib
HostBinaries = $BUILD_PREFIX/bin
HostLibraryExecutables = $BUILD_PREFIX/lib/qt6
EOF

  QMAKE_WRAPPER="${BUILD_PREFIX}/bin/qmake-target"

  # Wrapper for qmake that uses target Qt configuration
  cat > ${QMAKE_WRAPPER} << 'WRAPPER_EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/qmake6" -qtconf "QTCONF_PATH" "$@"
WRAPPER_EOF
  sed -i.bak "s|QTCONF_PATH|${PWD}/qt-target.conf|g" ${QMAKE_WRAPPER}
  rm ${QMAKE_WRAPPER}.bak
  chmod +x ${QMAKE_WRAPPER}
  ln -sf ${QMAKE_WRAPPER} ${BUILD_PREFIX}/bin/qmake
fi
