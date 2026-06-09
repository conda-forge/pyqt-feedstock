"""Verify that libpyqt6.so can be loaded by Qt Designer."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

if sys.platform == "win32":
    plugin_path = os.path.join(
        os.environ.get("PREFIX", sys.prefix),
        "Library", "plugins", "designer", "libpyqt6.dll"
    )
else:
    plugin_path = os.path.join(
        os.environ.get("PREFIX", sys.prefix),
        "lib", "qt6", "plugins", "designer", "libpyqt6.so"
    )

# Check file exists
if not os.path.isfile(plugin_path):
    print(f"FAIL: {plugin_path} not found")
    sys.exit(1)

# Check file type (Unix-only; skip on Windows)
import subprocess
if sys.platform != "win32":
    result = subprocess.run(
        ["file", plugin_path], capture_output=True, text=True
    )
    print(f"File: {result.stdout.strip()}")

# Try loading with QLibrary
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
