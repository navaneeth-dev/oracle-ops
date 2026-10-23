"""Mirror the established /data directory layout without moving existing files."""
import os
from pathlib import Path

root = Path('/zerofs')
paths = [
    '', 'usenet', 'usenet/incomplete', 'usenet/complete', 'torrents',
    'torrents/books', 'torrents/movies', 'torrents/music', 'torrents/tv',
    'torrents/audiobooks', 'media', 'media/books', 'media/movies',
    'media/music', 'media/tv',
]
for relative in paths:
    path = root / relative
    if path.is_symlink():
        raise RuntimeError(f'Refusing to initialize a symlink: {path}')
    path.mkdir(mode=0o775, exist_ok=True)
    os.chown(path, 1000, 1000)
    os.chmod(path, 0o775)
print('Initialized the existing TRaSH-style layout under /zerofs for UID/GID 1000.')
