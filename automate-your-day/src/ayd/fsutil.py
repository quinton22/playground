"""Small file helpers: interprocess lock (flock) and atomic replace. No-ops for locking where fcntl is missing."""

from __future__ import annotations

import contextlib
import os
import tempfile
from pathlib import Path

try:
    import fcntl
except ImportError:  # e.g. Windows: no interprocess locking available
    fcntl = None


@contextlib.contextmanager
def file_lock(path: Path):
    """Exclusive interprocess lock on a sidecar file; released when the block exits (or the process dies)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a+") as f:
        if fcntl:
            fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield
        finally:
            if fcntl:
                fcntl.flock(f, fcntl.LOCK_UN)


def atomic_write(path: Path, text: str) -> None:
    """Write via temp file + rename so readers never see a truncated file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(OSError):
            os.unlink(tmp)
        raise
