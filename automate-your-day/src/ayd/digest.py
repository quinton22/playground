"""Short deterministic summary (no agent): done / next / blockers / deadlines / failures. Doubles as standup."""

from __future__ import annotations

from datetime import datetime, timedelta

from . import journal, ledger, runner, tracks
from .config import Config


def _fmt(lines: list[str], kinds: str) -> list[str]:
    out = []
    for l in lines:
        p = l.split("|", 3)
        if len(p) == 4 and p[0] in kinds:
            out.append(f"- {'* ' if p[0] == 'W' else ''}{p[2]}: {p[3]}")
    return out


def build(cfg: Config, now: datetime) -> str:
    today = now.date()
    out = [f"# ayd digest {today} ({today:%a})"]
    prev = journal.previous_day(cfg, today)
    cur = journal.read_day(cfg, today).splitlines()
    prev_lines = prev[1].splitlines() if prev else []

    def section(title: str, items: list[str]) -> None:
        if items:
            out.extend(["", title] + items)

    section(f"Done {prev[0]}:" if prev else "Done:", _fmt(prev_lines, "AUW"))
    section("Done today:", _fmt(cur, "AUW"))
    section("Next:", _fmt(prev_lines + cur, "N"))
    blockers = [f"- {i.id} [{i.task}] {i.text}" for i in ledger.questions(cfg).by_status("O")]
    blockers += [f"- {i.id} [{i.task}] approve? {i.text}" for i in ledger.actions(cfg).by_status("P")]
    section("Blockers (need you; see `ayd inbox`):", blockers)
    section("Deadlines:", [f"- {t.slug}: {tracks.deadline_text(left)} ({t.meta.get('title', '')})"
                           for left, t in tracks.deadlines(cfg, today, cfg.nudge_days)])
    since = (now - timedelta(hours=24)).date()
    fails = [f"- {r.date} {r.time} {r.task}: {r.status}" for r in runner.read_runs(cfg)
             if r.date >= since and r.status in ("failed", "timeout")]
    section("Failures (24h):", fails)
    if len(out) == 1:
        out.append("\nNothing to report.")
    return "\n".join(out) + "\n"
