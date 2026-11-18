"""Build the briefing/prompt handed to the agent: rules + task + only the pertinent files."""

from __future__ import annotations

from datetime import date, datetime, timedelta

from . import journal, tracks
from .config import Config, Task

LEGEND = """\
FILE FORMAT (compact, one record per line, fields split by '|')
 journal: kind|HH:MM|task|text      track: YYYY-MM-DD|kind|text
 kinds: A=agent did  U=user did  N=next step  Q=open question for the user"""

RULES = """\
RULES
1. limits are HARD. Never exceed them, even if it seems helpful. If a step would exceed a limit, skip it and log a Q.
2. Log every outcome with the ayd CLI (below). Terse, one line per outcome, no prose. Include ids/links needed to resume.
3. For all unfinished work log an N line with the concrete next step. If unsure what to do next or what the user wants, log a Q, and ask the user directly if this is an interactive session.
4. Previous N/Q lines below are your to-do list: do them, and log what you did. Do not redo finished work.
5. Anything long-running or with a deadline belongs in a track (`ayd track new`), not just the day file.
6. Read only what is in this briefing plus what the task needs. Do not read older journal files unless a line points you to them.
CLI (config is preset via $AYD_CONFIG)
 ayd log <task> "<text>" [-k A|U|N|Q] [--track <slug>] [--date YYYY-MM-DD]
 ayd track new <slug> --title "<t>" [--due YYYY-MM-DD] | ayd track set <slug> <key> <value> | ayd track done <slug>"""


def _task_block(t: Task) -> str:
    lines = [f"TASK {t.name}: {t.do}"]
    if t.via:
        lines.append(f"via: {t.via}")
    if t.repos:
        lines.append("repos: " + ", ".join(t.repos))
    lines.append(f"limits (HARD): {t.limits or 'none given - ask the user (log a Q) before any outward-facing action'}")
    return "\n".join(lines)


def wrapup_day(cfg: Config, now: datetime) -> date:
    today = now.date()
    return today - timedelta(days=1) if cfg.wrapup and cfg.wrapup.covers == "yesterday" else today


def _context(cfg: Config, day: date) -> str:
    parts = []
    prev = journal.previous_day(cfg, day)
    if prev:
        parts.append(f"PREVIOUS JOURNAL {prev[0]}\n{prev[1].rstrip()}")
    else:
        parts.append("PREVIOUS JOURNAL: none (first run)")
    cur = journal.read_day(cfg, day)
    parts.append(f"JOURNAL {day} (so far)\n{cur.rstrip()}" if cur else f"JOURNAL {day}: empty")
    act = tracks.active(cfg)
    parts.append("ACTIVE TRACKS\n" + "\n".join(tracks.render(t) for t in act) if act else "ACTIVE TRACKS: none")
    return "\n\n".join(parts)


def build(cfg: Config, task: str | None, now: datetime) -> str:
    """Briefing for a task, for 'wrapup', or (task=None) for an interactive overview."""
    head = f"# ayd briefing {now:%Y-%m-%d %H:%M (%a)}"
    if task == "wrapup":
        w = cfg.wrapup
        if w is None:
            raise ValueError("no [wrapup] section in config")
        day = wrapup_day(cfg, now)
        scan = "\n".join(f"- {s}" for s in w.scan) or "- (nothing configured: do not scan anything)"
        body = (
            f"TASK wrapup for {day}: record work the USER did that is not yet in the journal, then set next steps.\n"
            f"1. Scan ONLY these sources for the user's activity on {day} (read-only; never send/post/modify):\n{scan}\n"
            f"   Log each as `ayd log wrapup \"<text>\" -k U --date {day}` (merge trivial items; skip duplicates already logged).\n"
            f"2. Review {day}'s journal and tracks. For every unfinished item log an N (`--date {day}`); if unsure what should happen next, log a Q"
            f"{' and ask the user now' if w.ask_user else ''}.\n"
            f"3. Update tracks with progress or status changes.\n"
            f"Always pass --date {day} to ayd log for journal entries."
        )
        ctx = _context(cfg, day)
    elif task:
        t = cfg.tasks[task]
        body = _task_block(t) + "\n\nDo this task now, then log outcomes and next steps."
        ctx = _context(cfg, now.date())
    else:
        listing = "\n".join(f"- {t.name} [{t.when}]: {t.do}" for t in cfg.tasks.values()) or "- (none)"
        body = "CONFIGURED TASKS\n" + listing + "\n\nPick up from the context below. Ask the user what to run if unclear."
        ctx = _context(cfg, now.date())
    return "\n\n".join([head, LEGEND, RULES, body, ctx]) + "\n"
