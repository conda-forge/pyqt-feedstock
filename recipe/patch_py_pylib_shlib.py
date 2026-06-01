import re, sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

old = (
    'if not self.py_pylib_shlib:\n'
    '            self.progress("The {0} plugin was disabled because a shared Python library couldn\'t be found.".format(user_name))\n'
    '            return'
)

new = (
    'if not self.py_pylib_shlib:\n'
    '            self.py_pylib_shlib = "libpython{}.{}.so".format(self.py_major_version, self.py_minor_version)'
)

count = content.count(old)
if count != 1:
    print(f"WARNING: found {count} matches (expected 1)", file=sys.stderr)
    sys.exit(1)

content = content.replace(old, new)
with open(path, 'w') as f:
    f.write(content)
print("Patched py_pylib_shlib fallback in", path)
