"""ayd command line interface."""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from datetime import date, datetime
from pathlib import Path

from . import brief, journal, schedule, tracks
from .config import STARTER, Config, ConfigError, find_config, load


def _now() -> datetime:
    return datetime.now()


def _cfg(args) -> Config:
    return load(find_config(args.config))


def _parse_day(s: str | None) -> date | None:
    return date.fromisoformat(s) if s else None


def run_agent(cfg: Config, agent: str, prompt: str, task: str, now: datetime) -> int:
    env = {**os.environ, "AYD_CONFIG": str(cfg.path)}
    try:
        rc = subprocess.run(shlex.split(agent), input=prompt, text=True, env=env).returncode
    except FileNotFoundError:
        print(f"ayd: agent command not found: {agent}", file=sys.stderr)
        rc = 127
    if rc:
        journal.append(cfg, "A", task, f"FAILED agent exit {rc}; retry next run", now)
    return rc


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
    print(f"config: {cfg.path}\ndata:   {cfg.data_dir}\nagent:  {cfg.agent}")
    for t in cfg.tasks.values():
        print(f"task {t.name:<14} {t.when:<16} {'cron ' + t.cron if t.cron else 'manual'}")
    for t in cfg.tasks.values():
        if not t.limits:
            print(f"warning: task '{t.name}' has no limits; the agent will be told to ask before any outward-facing action",
                  file=sys.stderr)
    if cfg.wrapup:
        w = cfg.wrapup
        print(f"wrapup {'':<12} {w.when:<16} {'cron ' + w.cron if w.cron else 'manual'}"
              f"  covers={w.covers} scan={len(w.scan)} ask_user={w.ask_user}")
    else:
        print("wrapup: not configured")
    return 0


def cmd_brief(args) -> int:
    cfg = _cfg(args)
    task = args.task
    if task and task != "wrapup" and task not in cfg.tasks:
        raise ConfigError(f"unknown task {task!r}")
    print(brief.build(cfg, task, _now()), end="")
    return 0


def cmd_run(args) -> int:
    if args.task == "wrapup":
        return cmd_wrapup(args)
    cfg = _cfg(args)
    if args.task not in cfg.tasks:
        raise ConfigError(f"unknown task {args.task!r} (have: {', '.join(cfg.tasks) or 'none'})")
    now = _now()
    prompt = brief.build(cfg, args.task, now)
    if args.dry_run:
        print(prompt, end="")
        return 0
    return run_agent(cfg, cfg.tasks[args.task].agent or cfg.agent, prompt, args.task, now)


def _notify(cmd: str, msg: str) -> None:
    if cmd:
        subprocess.run(cmd, shell=True, env={**os.environ, "AYD_MESSAGE": msg})


def cmd_wrapup(args) -> int:
    cfg = _cfg(args)
    if cfg.wrapup is None:
        raise ConfigError("no [wrapup] section in config")
    w, now = cfg.wrapup, _now()
    day = brief.wrapup_day(cfg, now)
    prompt = brief.build(cfg, "wrapup", now)
    if args.dry_run:
        print(prompt, end="")
        return 0
    if w.ask_user:
        if sys.stdin.isatty():
            print(f"Anything else you did on {day}? One item per line, blank line to finish.")
            while (line := input("> ").strip()):
                journal.append(cfg, "U", "user", line, now, day)
        else:
            msg = f"ayd: add extra work for {day} with: ayd add \"what you did\" --date {day}"
            journal.append(cfg, "Q", "wrapup", f"user not asked (no terminal); run: ayd add \"...\" --date {day}", now, day)
            _notify(w.notify, msg)
    if args.no_agent:
        return 0
    return run_agent(cfg, cfg.agent, prompt, "wrapup", now)


def cmd_log(args) -> int:
    cfg = _cfg(args)
    now = _now()
    if args.track:
        tracks.append(cfg, args.track, args.kind, args.text, now)
    journal.append(cfg, args.kind, args.task, (f"#{args.track} " if args.track else "") + args.text, now, _parse_day(args.date))
    return 0


def cmd_add(args) -> int:
    cfg = _cfg(args)
    journal.append(cfg, "U", "user", args.text, _now(), _parse_day(args.date))
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


def cmd_schedule(args) -> int:
    cfg = _cfg(args)
    entries = [(t.cron, f"run {t.name}") for t in cfg.tasks.values() if t.cron]
    if cfg.wrapup and cfg.wrapup.cron:
        entries.append((cfg.wrapup.cron, "wrapup"))
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


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="ayd", description="automate-your-day: config-driven daily work for AI agents")
    p.add_argument("--config", "-c", help="path to ayd.toml (default: $AYD_CONFIG, ./ayd.toml, ~/.config/ayd/ayd.toml)")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("init", help="write a starter config")
    s.add_argument("path", nargs="?")
    s.set_defaults(fn=cmd_init)

    sub.add_parser("check", help="validate config and show schedule").set_defaults(fn=cmd_check)

    s = sub.add_parser("brief", help="print the briefing an agent should read before working")
    s.add_argument("task", nargs="?", help="task name, 'wrapup', or omit for an overview")
    s.set_defaults(fn=cmd_brief)

    s = sub.add_parser("run", help="run a task with the configured agent")
    s.add_argument("task")
    s.add_argument("--dry-run", action="store_true", help="print the prompt instead of running the agent")
    s.add_argument("--no-agent", action="store_true", help=argparse.SUPPRESS)
    s.set_defaults(fn=cmd_run)

    s = sub.add_parser("wrapup", help="end-of-day/start-of-day scan, user prompt, and next steps")
    s.add_argument("--dry-run", action="store_true")
    s.add_argument("--no-agent", action="store_true", help="only ask the user; skip the agent scan")
    s.set_defaults(fn=cmd_wrapup)

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

    s = sub.add_parser("schedule", help="print (or install) crontab entries for scheduled tasks")
    s.add_argument("--install", action="store_true")
    s.add_argument("--uninstall", action="store_true")
    s.add_argument("--bin", default="ayd", help="path to the ayd executable for cron (default: ayd)")
    s.set_defaults(fn=cmd_schedule)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.fn(args)
    except (ConfigError, tracks.TrackError, ValueError) as e:
        print(f"ayd: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
