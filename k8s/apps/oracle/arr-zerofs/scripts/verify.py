"""Verify the shared filesystem as the same UID/GID used by the arr apps."""
import os
import uuid
from pathlib import Path

source = Path('/zerofs/torrents/movies') / ('.verify-' + uuid.uuid4().hex)
link = Path('/zerofs/media/movies') / source.name
try:
    with source.open('xb') as f:
        f.write(b'arr-zerofs-hardlink-check')
        f.flush()
        os.fsync(f.fileno())
    os.link(source, link)
    assert source.stat().st_ino == link.stat().st_ino
    assert source.stat().st_nlink == 2
    assert link.read_bytes() == b'arr-zerofs-hardlink-check'
    print('UID/GID 1000 write/read and cross-directory hardlink verification passed.')
finally:
    link.unlink(missing_ok=True)
    source.unlink(missing_ok=True)
