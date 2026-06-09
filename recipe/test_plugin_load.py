"""Verify that the PyQt6 Qt Designer plugin can be loaded."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

if sys.platform == "win32":
    plugin_path = os.path.join(
        os.environ.get("PREFIX", sys.prefix),
        "Library", "plugins", "designer", "libpyqt6.dll"
    )
elif sys.platform == "darwin":
    plugin_path = os.path.join(
        os.environ.get("PREFIX", sys.prefix),
        "lib", "qt6", "plugins", "designer", "libpyqt6.dylib"
    )
else:
    plugin_path = os.path.join(
        os.environ.get("PREFIX", sys.prefix),
        "lib", "qt6", "plugins", "designer", "libpyqt6.so"
    )

try:
    from PyQt6.QtCore import QLibrary

    lib = QLibrary(plugin_path)
    if lib.load():
        print(f"PASS: QLibrary.load() succeeded for {plugin_path}")
    else:
        print(f"FAIL: QLibrary.load() failed: {lib.errorString()}")
        sys.exit(1)
except Exception as e:
    print(f"FAIL: Exception while loading: {e}")
    sys.exit(1)

print("All checks passed.")
