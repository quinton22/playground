"""Compact per-day journal: journal/YYYY-MM-DD.ayd, one `kind|HH:MM|task|text` record per line.

kinds: A = agent did, U = user did, N = next step, Q = open question for the user.
"""

from __future__ import annotations

from datetime import date, datetime
from pathlib import Path

from .config import Config

KINDS = ("A", "U", "N", "Q")


def clean(text: str) -> str:
    """Single line, no field separators."""
    return " ".join(text.split()).replace("|", "/")


def day_file(cfg: Config, day: date) -> Path:
    return cfg.journal_dir / f"{day.isoformat()}.ayd"


def append(cfg: Config, kind: str, task: str, text: str, now: datetime, day: date | None = None) -> Path:
    if kind not in KINDS:
        raise ValueError(f"kind must be one of {', '.join(KINDS)}")
    day = day or now.date()
    path = day_file(cfg, day)
    path.parent.mkdir(parents=True, exist_ok=True)
    new = not path.exists()
    with path.open("a", encoding="utf-8") as f:
        if new:
            f.write(f"#ayd1 {day.isoformat()}\n")
        f.write(f"{kind}|{now:%H:%M}|{clean(task)}|{clean(text)}\n")
    return path


def read_day(cfg: Config, day: date) -> str:
    p = day_file(cfg, day)
    return p.read_text(encoding="utf-8") if p.exists() else ""


def previous_day(cfg: Config, before: date) -> tuple[date, str] | None:
    """Most recent journal file strictly before `before` (skips weekends/gaps)."""
    best: date | None = None
    if cfg.journal_dir.is_dir():
        for p in cfg.journal_dir.glob("*.ayd"):
            try:
                d = date.fromisoformat(p.stem)
            except ValueError:
                continue
            if d < before and (best is None or d > best):
                best = d
    return (best, read_day(cfg, best)) if best else None
