"""Print `--disable <module>` for every PyQt6 module not listed on the command line.

sip-build skips the configuration tests (which detect disabled features such as
PyQt_OpenGL_ES2) for modules passed with --enable, so the multimedia build
disables everything else instead and lets the tests run as in the pyqt6 build.

Usage: python pyqt_disable_flags.py <path to PyQt6 project.py> <module to keep>...
"""
import re
import sys

source = open(sys.argv[1]).read()
keep = set(sys.argv[2:])

m = re.search(r"self\.bindings_factories\s*=\s*\[(.*?)\]", source, re.S)
if m is None:
    sys.exit("ERROR: could not find bindings_factories in project.py")

modules = re.findall(r"\w+", m.group(1))

missing = keep - set(modules)
if missing:
    sys.exit(f"ERROR: unknown modules {sorted(missing)}")

print(" ".join(f"--disable {name}" for name in modules if name not in keep))
