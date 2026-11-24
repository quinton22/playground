"""Long-running / deadline tracks: tracks/<slug>.ayd.

Format:
    #ayd1 track
    @title=...          (meta lines: title, due=YYYY-MM-DD, status=active|paused|done, ...)
    2026-11-18|A|text   (entries: date|kind|text)
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path

from .config import NAME_RE, Config
from .fsutil import atomic_write, file_lock
from .journal import KINDS, clean

STATUSES = ("active", "paused", "done")
META_KEY = re.compile(r"^[a-z_]+$")


class TrackError(Exception):
    pass


@dataclass
class Track:
    slug: str
    meta: dict[str, str] = field(default_factory=dict)
    entries: list[str] = field(default_factory=list)

    @property
    def status(self) -> str:
        return self.meta.get("status", "active")


def path(cfg: Config, slug: str) -> Path:
    if not NAME_RE.match(slug):
        raise TrackError(f"invalid track name {slug!r} (lowercase letters/digits/-/_)")
    return cfg.tracks_dir / f"{slug}.ayd"


def save(cfg: Config, slug: str, meta: dict[str, str], entries: list[str]) -> None:
    lines = ["#ayd1 track"] + [f"@{k}={clean(v)}" for k, v in meta.items()] + entries
    atomic_write(path(cfg, slug), "\n".join(lines) + "\n")


def locked(cfg: Config, slug: str):
    """Hold for a whole read-modify-write (set_meta, append, compaction) so concurrent tasks never lose entries."""
    return file_lock(cfg.tracks_dir / f".{path(cfg, slug).stem}.lock")


def load(cfg: Config, slug: str) -> Track:
    p = path(cfg, slug)
    if not p.exists():
        raise TrackError(f"no such track: {slug}")
    t = Track(slug)
    for line in p.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or not line.strip():
            continue
        if line.startswith("@") and "=" in line:
            k, v = line[1:].split("=", 1)
            t.meta[k] = v
        else:
            t.entries.append(line)
    return t


def _check_meta(key: str, value: str) -> None:
    if not META_KEY.match(key):
        raise TrackError(f"invalid meta key {key!r}")
    if key == "due":
        try:
            date.fromisoformat(value)
        except ValueError:
            raise TrackError("due must be YYYY-MM-DD") from None
    if key == "status" and value not in STATUSES:
        raise TrackError(f"status must be one of {', '.join(STATUSES)}")


def create(cfg: Config, slug: str, title: str, due: str | None = None) -> Track:
    p = path(cfg, slug)
    meta = {"title": title, "status": "active"}
    if due:
        _check_meta("due", due)
        meta["due"] = due
    with locked(cfg, slug):
        if p.exists():
            raise TrackError(f"track already exists: {slug}")
        save(cfg, slug, meta, [])
    return load(cfg, slug)


def set_meta(cfg: Config, slug: str, key: str, value: str) -> None:
    _check_meta(key, value)
    with locked(cfg, slug):
        t = load(cfg, slug)
        t.meta[key] = value
        save(cfg, slug, t.meta, t.entries)


def append(cfg: Config, slug: str, kind: str, text: str, now: datetime, day: date | None = None) -> None:
    if kind not in KINDS:
        raise TrackError(f"kind must be one of {', '.join(KINDS)}")
    with locked(cfg, slug):
        load(cfg, slug)  # must exist
        with path(cfg, slug).open("a", encoding="utf-8") as f:
            f.write(f"{(day or now.date()).isoformat()}|{kind}|{clean(text)}\n")


def all_tracks(cfg: Config) -> list[Track]:
    if not cfg.tracks_dir.is_dir():
        return []
    return [load(cfg, p.stem) for p in sorted(cfg.tracks_dir.glob("*.ayd")) if NAME_RE.match(p.stem)]


def active(cfg: Config) -> list[Track]:
    """Non-done tracks, soonest deadline first (no deadline last)."""
    ts = [t for t in all_tracks(cfg) if t.status != "done"]
    return sorted(ts, key=lambda t: (t.meta.get("due") or "9999-99-99", t.slug))


def render(t: Track, tail: int = 12) -> str:
    head = f"== {t.slug} | " + " | ".join(f"{k}={v}" for k, v in t.meta.items())
    shown = t.entries[-tail:]
    lines = [head]
    if len(t.entries) > len(shown):
        lines.append(f"(+{len(t.entries) - len(shown)} earlier entries in tracks/{t.slug}.ayd)")
    return "\n".join(lines + shown)


def deadlines(cfg: Config, today: date, within: int) -> list[tuple[int, Track]]:
    """(days_left, track) for non-done tracks due within `within` days (negative = overdue)."""
    out = []
    for t in active(cfg):
        due = t.meta.get("due")
        if due:
            left = (date.fromisoformat(due) - today).days
            if left <= within:
                out.append((left, t))
    return sorted(out, key=lambda x: x[0])


def deadline_text(left: int) -> str:
    return f"OVERDUE by {-left}d" if left < 0 else "due today" if left == 0 else f"due in {left}d"
