"""Make the absolute paths that sip writes into a dist-info RECORD relative.

sip compares os.path.normcase()d file names with an un-normalised sys.prefix
when writing RECORD, which never matches on Windows. Files installed outside
site-packages (e.g. Library\\bin\\pyuic6.exe) then end up as absolute paths
with mixed slashes, which rattler-build can't relocate. Rewrite them the way
sip intends: relative to site-packages, with forward slashes.
"""

import os
import re
import sys
from pathlib import Path


def normalise(name):
    return re.sub(r"[-_.]+", "_", name).lower()


def fix_record(record, prefix):
    site_packages = record.parent.parent
    lines = []
    changed = 0
    for line in record.read_text().splitlines():
        path, digest, size = line.rsplit(",", 2)
        if os.path.isabs(path):
            if not os.path.normcase(os.path.abspath(path)).startswith(prefix):
                sys.exit(f"{record}: {path} is outside {prefix}")
            path = os.path.relpath(path, site_packages).replace("\\", "/")
            changed += 1
        lines.append(f"{path},{digest},{size}")
    record.write_text("\n".join(lines) + "\n")
    print(f"{record}: made {changed} entries relative")


def main(project):
    prefix = os.path.normcase(os.path.abspath(os.environ["PREFIX"]))
    site_packages = Path(os.environ["SP_DIR"])
    records = [
        d / "RECORD"
        for d in site_packages.glob("*.dist-info")
        if normalise(d.name[: -len(".dist-info")].rsplit("-", 1)[0]) == normalise(project)
    ]
    if not records:
        sys.exit(f"no dist-info for {project} in {site_packages}")
    for record in records:
        fix_record(record, prefix)


if __name__ == "__main__":
    main(sys.argv[1])
