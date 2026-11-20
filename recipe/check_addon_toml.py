"""Check that add-on module bindings were configured like the installed pyqt6.

The .toml files that sip installs next to each module's .sip files record the
tags and disabled features it was generated with; third-party sip bindings
that %Import these modules rely on them. A module's .toml is the union of the
.toml files of the modules it imports, so the expected value is derived from
the installed pyqt6 .toml files of each module's (transitive) imports.

Usage: python check_addon_toml.py <PyQt6 sip source dir> <staged PyQt6/bindings> <installed PyQt6/bindings> <module>...
"""
import re
import sys
from functools import lru_cache
from pathlib import Path

KEYS = ("module-tags", "module-disabled-features")

sip_dir, staged, installed = (Path(p) for p in sys.argv[1:4])
modules = sys.argv[4:]


def read_toml(path):
    text = path.read_text()
    out = {}
    for key in KEYS:
        m = re.search(rf"^{key}\s*=\s*\[(.*)\]\s*$", text, re.M)
        out[key] = frozenset(re.findall(r'"([^"]+)"', m.group(1))) if m else frozenset()

    return out


def imports(module):
    text = (sip_dir / module / f"{module}mod.sip").read_text()
    return re.findall(r"^%Import\s+(\w+)/", text, re.M)


@lru_cache(maxsize=None)
def expected(module):
    """Union of the installed pyqt6 .toml files of everything `module` imports."""
    result = {k: set() for k in KEYS}
    for dep in imports(module):
        installed_toml = installed / dep / f"{dep}.toml"
        dep_cfg = read_toml(installed_toml) if installed_toml.exists() else expected(dep)
        for k in KEYS:
            result[k] |= dep_cfg[k]

    return {k: frozenset(v) for k, v in result.items()}


ok = True
for m in modules:
    got, want = read_toml(staged / m / f"{m}.toml"), expected(m)
    print(f"{m}: {dict(got)}")
    if got != want:
        print(f"ERROR: {m}.toml does not match pyqt6: expected {dict(want)}")
        ok = False
sys.exit(0 if ok else 1)
