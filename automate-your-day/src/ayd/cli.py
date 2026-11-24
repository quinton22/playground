"""ayd command line interface."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

from . import (brief, compact, digest, history, journal, ledger, periods, report, runner,
               schedule, templates, tracks)
from .config import STARTER, Config, ConfigError, find_config, load


def _now() -> datetime:
    return datetime.now()


def _cfg(args) -> Config:
    return load(find_config(args.config))


def _parse_day(s: str | None) -> date | None:
    return date.fromisoformat(s) if s else None


def _notify(cmd: str, msg: str) -> None:
    if cmd:
        subprocess.run(cmd, shell=True, env={**os.environ, "AYD_MESSAGE": msg})


def _ask(cfg: Config, task: str, text: str, now: datetime, day: date | None = None) -> str:
    """Register a question for the user and journal it."""
    qid = ledger.questions(cfg).add(task, text, now)
    journal.append(cfg, "Q", task, f"{qid} {text}", now, day)
    return qid


# ---------------------------------------------------------------- setup / info

def cmd_init(args) -> int:
    p = Path(args.path or "ayd.toml")
    if p.exists():
        print(f"ayd: {p} already exists; not overwriting", file=sys.stderr)
        return 1
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(STARTER, encoding="utf-8")
    print(f"wrote {p}. Edit it (or ask your AI tool to, via the ayd-setup skill), then run `ayd check`.")
    return 0


def cmd_check(args) -> int:
    cfg = _cfg(args)
    print(f"config: {cfg.path}\ndata:   {cfg.data_dir}\nagent:  {cfg.agent}  (timeout {cfg.timeout // 60}m)")
    for t in cfg.tasks.values():
        extra = (" approval=ask" if t.approval == "ask" else "") + (f" requires={','.join(t.requires)}" if t.requires else "")
        print(f"task {t.name:<14} {t.when:<16} {'cron ' + t.cron if t.cron else 'manual'}{extra}")
    for label, sec in (("wrapup", cfg.wrapup), ("digest", cfg.digest), ("rollup", cfg.rollup)):
        if sec:
            print(f"{label:<19} {sec.when:<16} {'cron ' + sec.cron if sec.cron else 'manual'}")
    if cfg.wrapup:
        print(f"  wrapup: covers={cfg.wrapup.covers} scan={len(cfg.wrapup.scan)} ask_user={cfg.wrapup.ask_user}")
    for t in cfg.tasks.values():
        if not t.limits:
            print(f"warning: task '{t.name}' has no limits; the agent will be told to ask before any outward-facing action",
                  file=sys.stderr)
    for left, t in tracks.deadlines(cfg, _now().date(), cfg.nudge_days):
        print(f"warning: track '{t.slug}' {tracks.deadline_text(left)}", file=sys.stderr)
    return 0


def cmd_brief(args) -> int:
    cfg = _cfg(args)
    task = args.task
    if task and task != "wrapup" and task not in cfg.tasks:
        raise ConfigError(f"unknown task {task!r}")
    print(brief.build(cfg, task, _now()), end="")
    return 0


# ---------------------------------------------------------------- running

def cmd_run(args) -> int:
    if args.task == "wrapup":
        return cmd_wrapup(args)
    cfg = _cfg(args)
    if args.task not in cfg.tasks:
        raise ConfigError(f"unknown task {args.task!r} (have: {', '.join(cfg.tasks) or 'none'})")
    task, now = cfg.tasks[args.task], _now()
    reason = None if args.force else runner.unmet(cfg, task, now)
    if args.dry_run:
        if reason:
            print(f"(would be skipped: {reason})", file=sys.stderr)
        print(brief.build(cfg, args.task, now), end="")
        return 0
    if reason:
        runner.record(cfg, now, task.name, "skipped", note=reason)
        print(f"ayd: skipped {task.name}: {reason}", file=sys.stderr)
        return 0
    prompt = brief.build(cfg, args.task, now)
    return runner.run_agent(cfg, task.name, task.agent or cfg.agent, prompt, now, task.timeout).exit_code


def cmd_start(args) -> int:
    """Interactive entry point: same prerequisite check, overlap guard and run recording as `ayd run`."""
    cfg, now, key = _cfg(args), _now(), args.task
    if key == "wrapup":
        if cfg.wrapup is None:
            raise ConfigError("no [wrapup] section in config")
    elif key not in cfg.tasks:
        raise ConfigError(f"unknown task {key!r} (have: {', '.join(cfg.tasks) or 'none'})")
    reason = None
    if key in cfg.tasks and not args.force:
        reason = runner.unmet(cfg, cfg.tasks[key], now)
    reason = reason or runner.session_start(cfg, key)
    if reason:
        runner.record(cfg, now, key, "skipped", note=reason)
        print(f"ayd: do not start {key}: {reason}", file=sys.stderr)
        return 3
    print(brief.build(cfg, key, now), end="")
    return 0


def cmd_finish(args) -> int:
    cfg = _cfg(args)
    runner.session_finish(cfg, args.task, _now(), ok=not args.failed, note=args.note or "")
    return 0


def cmd_wrapup(args) -> int:
    cfg = _cfg(args)
    if cfg.wrapup is None:
        raise ConfigError("no [wrapup] section in config")
    w, now = cfg.wrapup, _now()
    day = brief.wrapup_day(cfg, now)
    if args.dry_run:
        print(brief.build(cfg, "wrapup", now), end="")
        return 0
    if w.ask_user:
        if sys.stdin.isatty():
            print(f"Anything else you did on {day}? One item per line, blank line to finish.")
            while line := input("> ").strip():
                journal.append(cfg, "U", "user", line, now, day)
        else:
            _ask(cfg, "wrapup", f"user not asked (no terminal); run: ayd add \"...\" --date {day}", now, day)
            _notify(w.notify, f"ayd: add extra work for {day} with: ayd add \"what you did\" --date {day}")
    if getattr(args, "no_agent", False):
        return 0
    prompt = brief.build(cfg, "wrapup", now)  # built after the entries above so the agent sees them
    return runner.run_agent(cfg, "wrapup", cfg.agent, prompt, now).exit_code


def cmd_digest(args) -> int:
    cfg, now = _cfg(args), _now()
    text = digest.build(cfg, now)
    print(text, end="")
    if args.notify:
        if not (cfg.digest and cfg.digest.notify):
            raise ConfigError("no [digest] notify command configured")
        _notify(cfg.digest.notify, text)
    return 0


def cmd_stats(args) -> int:
    cfg = _cfg(args)
    rows = runner.stats(cfg, _now().date() - timedelta(days=args.days), args.task)
    if not rows:
        print("no runs recorded")
        return 0
    print(f"last {args.days} days (tokens are rough chars/4 estimates)")
    print(f"{'task':<16}{'runs':>5}{'ok':>5}{'fail':>5}{'skip':>5}{'avg s':>7}{'~tok in':>9}{'~tok out':>9}")
    for r in rows:
        avg = r["secs"] // r["runs"] if r["runs"] else 0
        print(f"{r['task']:<16}{r['runs']:>5}{r['ok']:>5}{r['failed']:>5}{r['skipped']:>5}{avg:>7}{r['tin']:>9}{r['tout']:>9}")
    return 0


# ---------------------------------------------------------------- recording

def cmd_log(args) -> int:
    cfg, now = _cfg(args), _now()
    text = args.text
    if args.kind == "Q":
        qid = ledger.questions(cfg).add(args.task, text, now)
        text = f"{qid} {text}"
        print(qid)
    day = _parse_day(args.date)
    if args.track:
        tracks.append(cfg, args.track, args.kind, text, now, day)
    journal.append(cfg, args.kind, args.task, (f"#{args.track} " if args.track else "") + text, now, day)
    return 0


def cmd_add(args) -> int:
    cfg = _cfg(args)
    journal.append(cfg, "W" if args.win else "U", "user", args.text, _now(), _parse_day(args.date))
    return 0


def cmd_track(args) -> int:
    cfg = _cfg(args)
    if args.action == "new":
        tracks.create(cfg, args.slug, args.title or args.slug, args.due)
    elif args.action == "set":
        tracks.set_meta(cfg, args.slug, args.key, args.value)
    elif args.action == "done":
        tracks.set_meta(cfg, args.slug, "status", "done")
    elif args.action == "ls":
        for t in tracks.all_tracks(cfg):
            print(f"{t.slug:<20} {t.status:<7} due={t.meta.get('due', '-'):<10} {t.meta.get('title', '')}")
    elif args.action == "show":
        print(tracks.render(tracks.load(cfg, args.slug), tail=10**6))
    return 0


# ---------------------------------------------------------------- questions & approvals

def cmd_inbox(args) -> int:
    cfg = _cfg(args)
    qs, acts = ledger.questions(cfg).by_status("O"), ledger.actions(cfg).by_status("P")
    for i in qs:
        print(f"{i.id:<4} question [{i.task}] {i.text}")
    for i in acts:
        print(f"{i.id:<4} approve? [{i.task}] {i.text}")
    if not (qs or acts):
        print("inbox empty")
    return 0


def _item(cfg: Config, id_: str, prefix: str):
    led, item = ledger.find(cfg, id_)
    if led.prefix != prefix:
        raise ConfigError(f"{id_} is not {'a question' if prefix == 'q' else 'an action'}")
    return led, item


def cmd_answer(args) -> int:
    cfg = _cfg(args)
    led, item = _item(cfg, args.id, "q")
    led.set_status(item.id, "A", args.text)
    journal.append(cfg, "U", "user", f"{item.id} answer: {args.text}", _now())
    return 0


def cmd_approve(args) -> int:
    cfg = _cfg(args)
    for id_ in args.ids:
        led, item = _item(cfg, id_, "a")
        led.set_status(item.id, "A")
        print(f"approved {item.id}: {item.text}")
    return 0


def cmd_reject(args) -> int:
    cfg = _cfg(args)
    led, item = _item(cfg, args.id, "a")
    led.set_status(item.id, "R", args.reason or "rejected")
    return 0


def cmd_propose(args) -> int:
    cfg = _cfg(args)
    if args.task not in cfg.tasks:
        raise ConfigError(f"unknown task {args.task!r}")
    now = _now()
    aid = ledger.actions(cfg).add(args.task, args.text, now)
    journal.append(cfg, "N", args.task, f"{aid} awaiting approval: {args.text}", now)
    print(aid)
    return 0


def cmd_close(args) -> int:
    cfg = _cfg(args)
    for id_ in args.ids:
        led, item = ledger.find(cfg, id_)
        led.set_status(item.id, "X")
    return 0


# ---------------------------------------------------------------- history: compact, rollup, report

def cmd_compact(args) -> int:
    cfg = _cfg(args)
    r = compact.compact(cfg, _now().date(), args.keep_days, args.keep_entries, args.dry_run)
    verb = "would archive" if args.dry_run else "archived"
    print(f"{verb}: {r['days']} journal days, {r['track_entries']} track entries, {r['ledger_items']} closed ledger items")
    return 0


def cmd_rollup(args) -> int:
    cfg, now = _cfg(args), _now()
    if args.action == "add":
        history.rollup_add(cfg, periods.parse(args.period, now.date()).label, args.kind, args.text)
        return 0
    if args.action == "show":
        print("\n".join(history.rollup_read(cfg, periods.parse(args.period, now.date()).label)))
        return 0
    spec = args.period or (cfg.rollup.covers if cfg.rollup else "this-week")
    period = periods.parse(spec, now.date())
    prompt, info = report.build_rollup(cfg, period)
    if args.dry_run:
        print(prompt, end="")
        return 0
    src = history.count_lines(cfg, period)  # fingerprint: the rollup is only trusted while this is still true
    res = runner.run_agent(cfg, "rollup", cfg.agent, prompt, now)
    if res.status != "ok":
        return res.exit_code
    lines = report.parse_rollup_output(res.out)
    if not lines:
        print("ayd: agent output had no `H|`/`M|`/`C|` lines; rollup not saved", file=sys.stderr)
        return 1
    p = history.rollup_write(cfg, period.label, lines, src=src)
    print(f"\nsaved {len(lines)} lines to {p}", file=sys.stderr)
    return 0


def cmd_report(args) -> int:
    cfg, now = _cfg(args), _now()
    if args.from_ or args.to:
        if not (args.from_ and args.to):
            raise ConfigError("use --from and --to together")
        period = periods.custom(date.fromisoformat(args.from_), date.fromisoformat(args.to))
    else:
        period = periods.parse(args.period or report.DEFAULT_PERIOD[args.kind], now.date())
    questions = Path(args.questions).expanduser().read_text(encoding="utf-8") if args.questions else None
    prompt, info = report.build_report(cfg, args.kind, period, questions=questions, ask=args.ask,
                                       target=args.target, note=args.note)
    print(f"ayd: evidence {info['chars']} chars ({info['rollups']} rollups, {info['days']} raw days, {info['tracks']} tracks)",
          file=sys.stderr)
    if info["chars"] > history.PACK_WARN_CHARS:
        print("ayd: evidence is large; run `ayd rollup run --period <week|month>` for older periods to shrink it", file=sys.stderr)
    if args.dry_run:
        print(prompt, end="")
        return 0
    res = runner.run_agent(cfg, "report", cfg.agent, prompt, now)
    if res.status != "ok":
        return res.exit_code
    if not res.out.strip():
        print("ayd: agent produced no output", file=sys.stderr)
        return 1
    if args.out:
        out = Path(args.out).expanduser()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(res.out, encoding="utf-8")
    else:
        out = _write_new(cfg.reports_dir / f"{args.kind}-{period.label.replace('..', '_')}.md", res.out)
    print(f"\nsaved to {out}", file=sys.stderr)
    return 0


def _write_new(base: Path, text: str) -> Path:
    """Create base (or base-2, base-3, ...) exclusively so concurrent/repeated runs never overwrite a report."""
    base.parent.mkdir(parents=True, exist_ok=True)
    for n in range(1, 10_000):
        p = base if n == 1 else base.with_name(f"{base.stem}-{n}{base.suffix}")
        try:
            fd = os.open(p, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            continue
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        return p
    raise OSError(f"could not allocate a report file near {base}")


def cmd_template(args) -> int:
    if args.action == "ls":
        for n in templates.names():
            print(f"{n:<18} {templates.TEMPLATES[n]['desc']}")
        return 0
    path = find_config(args.config)
    name = args.as_name or templates.TEMPLATES.get(args.name, {}).get("default")
    snippet = templates.render(args.name, args.as_name)
    old = path.read_text(encoding="utf-8")
    path.write_text(old.rstrip("\n") + "\n\n" + snippet, encoding="utf-8")
    try:
        load(path)
    except ConfigError:
        path.write_text(old, encoding="utf-8")
        raise
    print(f"added [tasks.{name}] to {path}; edit it (e.g. repos, limits), then `ayd check`")
    return 0


# ---------------------------------------------------------------- scheduling

def cmd_schedule(args) -> int:
    cfg = _cfg(args)
    entries = [(t.cron, f"run {t.name}") for t in cfg.tasks.values() if t.cron]
    if cfg.wrapup and cfg.wrapup.cron:
        entries.append((cfg.wrapup.cron, "wrapup"))
    if cfg.digest and cfg.digest.cron:
        entries.append((cfg.digest.cron, "digest --notify" if cfg.digest.notify else "digest"))
    if cfg.rollup and cfg.rollup.cron:
        entries.append((cfg.rollup.cron, "rollup run"))
    block = schedule.crontab_block(entries, str(cfg.path), args.bin)
    if not (args.install or args.uninstall):
        print(block, end="")
        print("# Cron has a minimal PATH and no terminal: use absolute paths for ayd and your agent CLI.", file=sys.stderr)
        return 0
    cur = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
    existing = cur.stdout if cur.returncode == 0 else ""
    new = schedule.strip_block(existing) if args.uninstall else schedule.merge_crontab(existing, block)
    subprocess.run(["crontab", "-"], input=new, text=True, check=True)
    print("crontab updated" if args.install else "ayd entries removed from crontab")
    return 0


# ---------------------------------------------------------------- parser

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="ayd", description="automate-your-day: config-driven daily work for AI agents")
    p.add_argument("--config", "-c", help="path to ayd.toml (default: $AYD_CONFIG, ./ayd.toml, ~/.config/ayd/ayd.toml)")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("init", help="write a starter config")
    s.add_argument("path", nargs="?")
    s.set_defaults(fn=cmd_init)
    sub.add_parser("check", help="validate config; show schedule, warnings, deadlines").set_defaults(fn=cmd_check)

    s = sub.add_parser("brief", help="print the briefing an agent should read before working")
    s.add_argument("task", nargs="?", help="task name, 'wrapup', or omit for an overview")
    s.set_defaults(fn=cmd_brief)

    s = sub.add_parser("run", help="run a task with the configured agent")
    s.add_argument("task")
    s.add_argument("--dry-run", action="store_true", help="print the prompt instead of running the agent")
    s.add_argument("--force", action="store_true", help="ignore the task's `requires`")
    s.set_defaults(fn=cmd_run)

    s = sub.add_parser("start", help="(interactive agents) check requirements, take the run slot, print the briefing")
    s.add_argument("task", help="task name or 'wrapup'")
    s.add_argument("--force", action="store_true", help="ignore the task's `requires`")
    s.set_defaults(fn=cmd_start)
    s = sub.add_parser("finish", help="(interactive agents) record the run as done and release the slot")
    s.add_argument("task")
    s.add_argument("--failed", action="store_true")
    s.add_argument("--note")
    s.set_defaults(fn=cmd_finish)

    s = sub.add_parser("wrapup", help="end-of-day/start-of-day scan, user prompt, and next steps")
    s.add_argument("--dry-run", action="store_true")
    s.add_argument("--no-agent", action="store_true", help="only ask the user; skip the agent scan")
    s.set_defaults(fn=cmd_wrapup)

    s = sub.add_parser("digest", help="short summary: done / next / blockers / deadlines / failures")
    s.add_argument("--notify", action="store_true", help="also send it via [digest] notify")
    s.set_defaults(fn=cmd_digest)

    s = sub.add_parser("stats", help="run counts, durations, rough token estimates")
    s.add_argument("--days", type=int, default=30)
    s.add_argument("--task")
    s.set_defaults(fn=cmd_stats)

    s = sub.add_parser("log", help="append a record to the day journal (and optionally a track)")
    s.add_argument("task")
    s.add_argument("text")
    s.add_argument("-k", "--kind", default="A", choices=journal.KINDS)
    s.add_argument("--track")
    s.add_argument("--date", help="journal day YYYY-MM-DD (default today)")
    s.set_defaults(fn=cmd_log)

    s = sub.add_parser("add", help="record extra work you did yourself")
    s.add_argument("text")
    s.add_argument("--date")
    s.add_argument("--win", action="store_true", help="record as a notable accomplishment (W)")
    s.set_defaults(fn=cmd_add)

    s = sub.add_parser("track", help="manage long-running / deadline tracks")
    ts = s.add_subparsers(dest="action", required=True)
    n = ts.add_parser("new")
    n.add_argument("slug")
    n.add_argument("--title")
    n.add_argument("--due", help="YYYY-MM-DD")
    st = ts.add_parser("set")
    st.add_argument("slug")
    st.add_argument("key")
    st.add_argument("value")
    ts.add_parser("done").add_argument("slug")
    ts.add_parser("ls")
    ts.add_parser("show").add_argument("slug")
    s.set_defaults(fn=cmd_track)

    sub.add_parser("inbox", help="questions and proposed actions waiting on you").set_defaults(fn=cmd_inbox)
    s = sub.add_parser("answer", help="answer a question (qN)")
    s.add_argument("id")
    s.add_argument("text")
    s.set_defaults(fn=cmd_answer)
    s = sub.add_parser("approve", help="approve proposed action(s) (aN)")
    s.add_argument("ids", nargs="+")
    s.set_defaults(fn=cmd_approve)
    s = sub.add_parser("reject", help="reject a proposed action (aN) with an optional reason")
    s.add_argument("id")
    s.add_argument("reason", nargs="?")
    s.set_defaults(fn=cmd_reject)
    s = sub.add_parser("propose", help="(agents) propose an outward action for approval")
    s.add_argument("task")
    s.add_argument("text")
    s.set_defaults(fn=cmd_propose)
    s = sub.add_parser("close", help="close handled questions/actions")
    s.add_argument("ids", nargs="+")
    s.set_defaults(fn=cmd_close)

    s = sub.add_parser("compact", help="archive old journal days/track entries (reports still read them)")
    s.add_argument("--keep-days", type=int, default=60)
    s.add_argument("--keep-entries", type=int, default=30)
    s.add_argument("--dry-run", action="store_true")
    s.set_defaults(fn=cmd_compact)

    s = sub.add_parser("rollup", help="weekly/monthly summaries that make reviews cheap")
    rs = s.add_subparsers(dest="action", required=True)
    r = rs.add_parser("run", help="have the agent write the rollup")
    r.add_argument("--period", help="e.g. this-week, last-week, 2026-W47, 2026-10 (default: [rollup] covers)")
    r.add_argument("--dry-run", action="store_true")
    r = rs.add_parser("add", help="add a line by hand")
    r.add_argument("period")
    r.add_argument("text")
    r.add_argument("-k", "--kind", default="H", choices=history.ROLLUP_KINDS)
    rs.add_parser("show").add_argument("period")
    s.set_defaults(fn=cmd_rollup)

    s = sub.add_parser("report", help="write a review, promo packet, accomplishment list, or review answers from the record")
    s.add_argument("kind", choices=report.REPORT_KINDS, help="; ".join(f"{k}: {v}" for k, v in report.KIND_HELP.items()))
    s.add_argument("--period", help="2026, 2026-Q4, 2026-H1, 2026-11, last-quarter, ... (default depends on kind)")
    s.add_argument("--from", dest="from_", help="custom start YYYY-MM-DD")
    s.add_argument("--to", help="custom end YYYY-MM-DD")
    s.add_argument("--questions", help="file with the review questions to answer")
    s.add_argument("--ask", help="free-form request (kind 'ask')")
    s.add_argument("--target", help="promo: target role/level; others: audience or goal")
    s.add_argument("--note", help="extra context: tone, audience, what to emphasize")
    s.add_argument("--out", help="output file (default: <data_dir>/reports/)")
    s.add_argument("--dry-run", action="store_true", help="print the prompt + evidence instead of running the agent")
    s.set_defaults(fn=cmd_report)

    s = sub.add_parser("template", help="list or add starter task templates")
    s.add_argument("action", choices=["ls", "add"])
    s.add_argument("name", nargs="?")
    s.add_argument("--as", dest="as_name", help="task name to use instead of the template default")
    s.set_defaults(fn=cmd_template)

    s = sub.add_parser("schedule", help="print (or install) crontab entries for scheduled work")
    s.add_argument("--install", action="store_true")
    s.add_argument("--uninstall", action="store_true")
    s.add_argument("--bin", default="ayd", help="path to the ayd executable for cron (default: ayd)")
    s.set_defaults(fn=cmd_schedule)
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.cmd == "template" and args.action == "add" and not args.name:
        parser.error("template add needs a name (see `ayd template ls`)")
    try:
        return args.fn(args)
    except (ConfigError, tracks.TrackError, ValueError, KeyError) as e:
        print(f"ayd: {e.args[0] if isinstance(e, KeyError) and e.args else e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
