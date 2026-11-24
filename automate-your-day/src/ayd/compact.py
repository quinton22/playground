"""Archive old journal days and track entries so briefings stay small (reports still read the archive)."""

from __future__ import annotations

from datetime import date, timedelta

from . import ledger, tracks
from .config import Config
from .history import track_archive_path


def compact(cfg: Config, today: date, keep_days: int = 60, keep_entries: int = 30, dry_run: bool = False) -> dict:
    cutoff = today - timedelta(days=keep_days)
    res = {"days": 0, "track_entries": 0, "ledger_items": 0}

    if cfg.journal_dir.is_dir():
        for p in sorted(cfg.journal_dir.glob("*.ayd")):
            try:
                d = date.fromisoformat(p.stem)
            except ValueError:
                continue
            if d >= cutoff:
                continue
            res["days"] += 1
            if dry_run:
                continue
            lines = [l for l in p.read_text(encoding="utf-8").splitlines() if l and not l.startswith("#")]
            a = cfg.journal_dir / "archive" / f"{d:%Y-%m}.ayd"
            a.parent.mkdir(parents=True, exist_ok=True)
            new = not a.exists()
            with a.open("a", encoding="utf-8") as f:
                if new:
                    f.write("#ayd1 archive: YYYY-MM-DD|kind|HH:MM|task|text\n")
                f.writelines(f"{d.isoformat()}|{l}\n" for l in lines)
            p.unlink()

    for slug in [t.slug for t in tracks.all_tracks(cfg)]:
        with tracks.locked(cfg, slug):
            t = tracks.load(cfg, slug)  # reload under the lock: other tasks may have appended
            if len(t.entries) <= keep_entries:
                continue
            old, keep = t.entries[:-keep_entries], t.entries[-keep_entries:]
            res["track_entries"] += len(old)
            if dry_run:
                continue
            a = track_archive_path(cfg, slug)
            a.parent.mkdir(parents=True, exist_ok=True)
            new = not a.exists()
            with a.open("a", encoding="utf-8") as f:
                if new:
                    f.write("#ayd1 track archive\n")
                f.writelines(e + "\n" for e in old)
            tracks.save(cfg, slug, t.meta, keep)

    for led in (ledger.questions(cfg), ledger.actions(cfg)):
        if dry_run:
            res["ledger_items"] += sum(1 for i in led.by_status("X") if i.date < cutoff.isoformat())
        else:
            res["ledger_items"] += led.purge_closed(cutoff)
    return res
