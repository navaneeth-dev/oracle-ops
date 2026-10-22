"""Check arr-style hardlink and rename semantics on a fio test file."""
import argparse
import json
import os
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--gib", type=int, default=2, choices=[2, 8, 20])
args = parser.parse_args()
root = Path("/data/fio")
source = root / f"media-{args.gib}GiB.bin"
link = root / "hardlink-check.bin"
renamed = root / "rename-check.bin"
try:
    os.link(source, link)
    assert source.stat().st_ino == link.stat().st_ino
    os.rename(link, renamed)
    assert source.stat().st_ino == renamed.stat().st_ino
    assert source.stat().st_nlink == 2
    with source.open("rb") as a, renamed.open("rb") as b:
        assert a.read(1024**2) == b.read(1024**2)
    print(json.dumps({"hardlink": "passed", "rename": "passed", "links": 2}))
finally:
    link.unlink(missing_ok=True)
    renamed.unlink(missing_ok=True)
