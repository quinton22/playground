"""Read the whole record (live + archived) and build compact evidence packs for rollups/reports.

Rollups: rollups/<period>.ayd with lines `kind|text`; kinds H=accomplishment+impact, M=metric, C=carry-over/context.
Archive (written by `ayd compact`): journal/archive/YYYY-MM.ayd lines `YYYY-MM-DD|<journal line>`,
tracks/archive/<slug>.ayd lines identical to track entries.
"""

from __future__ import annotations

from datetime import date, timedelta
from pathlib import Path

from . import tracks
from .config import Config
from .fsutil import atomic_write
from .journal import clean
from .periods import Period, containing

ROLLUP_KINDS = ("H", "M", "C")
PACK_WARN_CHARS = 80_000


def days(cfg: Config, start: date, end: date) -> dict[date, list[str]]:
    out: dict[date, list[str]] = {}

    def add(d: date, line: str) -> None:
        if start <= d <= end:
            out.setdefault(d, []).append(line)

    if cfg.journal_dir.is_dir():
        for p in cfg.journal_dir.glob("*.ayd"):
            try:
                d = date.fromisoformat(p.stem)
            except ValueError:
                continue
            if start <= d <= end:
                for line in p.read_text(encoding="utf-8").splitlines():
                    if line and not line.startswith("#"):
                        add(d, line)
        arch = cfg.journal_dir / "archive"
        if arch.is_dir():
            for p in arch.glob("*.ayd"):
                for line in p.read_text(encoding="utf-8").splitlines():
                    if line and not line.startswith("#"):
                        ds, _, rest = line.partition("|")
                        try:
                            add(date.fromisoformat(ds), rest)
                        except ValueError:
                            pass
    return out


def track_archive_path(cfg: Config, slug: str) -> Path:
    return cfg.tracks_dir / "archive" / f"{slug}.ayd"


def track_entries(cfg: Config, slug: str) -> list[str]:
    p = track_archive_path(cfg, slug)
    old = [l for l in p.read_text(encoding="utf-8").splitlines() if l and not l.startswith("#")] if p.exists() else []
    return old + tracks.load(cfg, slug).entries


def rollup_path(cfg: Config, label: str) -> Path:
    return cfg.rollups_dir / f"{label}.ayd"


def rollup_read(cfg: Config, label: str) -> list[str]:
    p = rollup_path(cfg, label)
    if not p.exists():
        return []
    return [l for l in p.read_text(encoding="utf-8").splitlines() if l and not l.startswith("#")]


def rollup_src(cfg: Config, label: str) -> int | None:
    """Number of source journal lines the rollup was built from (None if hand-written)."""
    p = rollup_path(cfg, label)
    if p.exists():
        head = p.read_text(encoding="utf-8").splitlines()[:1]
        if head and " src=" in head[0]:
            try:
                return int(head[0].rsplit(" src=", 1)[1])
            except ValueError:
                return None
    return None


def count_lines(cfg: Config, period: Period) -> int:
    return sum(len(v) for v in days(cfg, period.start, period.end).values())


def rollup_write(cfg: Config, label: str, lines: list[str], src: int | None = None) -> Path:
    p = rollup_path(cfg, label)
    head = f"#ayd1 rollup {label}" + (f" src={src}" if src is not None else "")
    atomic_write(p, head + "\n" + "".join(l + "\n" for l in lines))
    return p


def rollup_add(cfg: Config, label: str, kind: str, text: str) -> None:
    if kind not in ROLLUP_KINDS:
        raise ValueError(f"rollup kind must be one of {', '.join(ROLLUP_KINDS)}")
    rollup_write(cfg, label, rollup_read(cfg, label) + [f"{kind}|{clean(text)}"], rollup_src(cfg, label))


def pack(cfg: Config, period: Period, exclude: str | None = None) -> tuple[str, dict]:
    """Evidence for `period`: existing rollups where they fully cover a month/week, raw days elsewhere, plus tracks."""
    covered: set[date] = set()
    segs: list[tuple[date, str]] = []  # (start, text)
    used = 0

    def try_unit(unit: str) -> None:
        nonlocal used
        cur = period.start
        while cur <= period.end:
            sub = containing(unit, cur)
            nxt = sub.end + timedelta(days=1)
            if sub.start >= period.start and sub.end <= period.end and sub.label != exclude \
                    and not any(d in covered for d in sub.days()):
                lines = rollup_read(cfg, sub.label)
                if lines and rollup_src(cfg, sub.label) == count_lines(cfg, sub):
                    # fresh: nothing was logged for these days since it was built, so it replaces them
                    segs.append((sub.start, f"## rollup {sub.label}\n" + "\n".join(lines)))
                    covered.update(sub.days())
                    used += 1
                elif lines:
                    # hand-written or out of date: keep it as a summary but do not hide the raw days
                    segs.append((sub.start, f"## rollup {sub.label} (not verified current; raw days follow)\n" + "\n".join(lines)))
            cur = nxt

    try_unit("month")
    try_unit("week")
    n_roll = used
    raw = days(cfg, period.start, period.end)
    n_days = 0
    for d in sorted(raw):
        if d not in covered:
            segs.append((d, f"## {d}\n" + "\n".join(raw[d])))
            n_days += 1
    segs.sort(key=lambda s: s[0])

    parts = [s[1] for s in segs] or ["(no journal data in this period)"]
    tr = []
    for t in tracks.all_tracks(cfg):
        ents = [e for e in track_entries(cfg, t.slug) if period.start.isoformat() <= e.split("|", 1)[0] <= period.end.isoformat()]
        if ents:
            tr.append(f"== {t.slug} | " + " | ".join(f"{k}={v}" for k, v in t.meta.items()) + "\n" + "\n".join(ents))
    text = "\n\n".join(parts)
    if tr:
        text += "\n\n# TRACKS (entries in period)\n" + "\n\n".join(tr)
    return text, {"rollups": n_roll, "days": n_days, "tracks": len(tr), "chars": len(text)}
