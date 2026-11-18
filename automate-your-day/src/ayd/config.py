"""Load and validate the user's ayd.toml."""

from __future__ import annotations

import os
import re
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

from .schedule import parse_duration, parse_when

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
DEFAULT_AGENT = "claude -p"
ROLLUP_COVERS = ("this-week", "last-week", "this-month", "last-month")
REQ_RE = re.compile(r"^(?:(ran|no-questions|no-pending):)?([a-z0-9][a-z0-9_-]*)$")

STARTER = '''\
# ayd config. Keep it short: each task says WHAT, VIA what, and the HARD LIMITS.
[ayd]
data_dir = "./ayd-data"      # journal/ (one file per day), tracks/, rollups/, reports/ live here
agent = "claude -p"          # command that receives the prompt on stdin
# timeout = "1h"             # kill a run that takes longer
# nudge_days = 7             # flag track deadlines this close

[tasks.email]
do = "Triage unread email and prepare replies"
via = "Outlook connector"
limits = "Create drafts only. Never send, delete, or archive anything."
when = "weekdays 09:00"      # manual | every 30m | every 2h | daily 09:00 | weekdays 09:00 | mon,wed 08:00

[tasks.tickets]
do = "Take my newly assigned Jira tickets and start implementing them"
via = "Atlassian connector"
repos = ["~/code/my-service"]
limits = "Push to feature branches only. Never open PRs. Never touch main."
when = "manual"
approval = "auto"            # ask = agent only proposes outward actions; you run `ayd approve`
# requires = ["email", "no-questions:email"]   # only run if these hold today

[wrapup]
when = "weekdays 17:30"
covers = "today"             # today | yesterday (use yesterday if wrapup runs next morning)
scan = ["sent email (Outlook)", "Slack messages I sent", "calendar meetings attended"]
ask_user = true              # also ask me for extra items I did
# notify = "notify-send ayd \\"$AYD_MESSAGE\\""   # run when asking but no terminal is attached

# [digest]                   # short summary: done / next / blockers / deadlines
# when = "weekdays 08:45"
# notify = "notify-send ayd \\"$AYD_MESSAGE\\""

# [rollup]                   # compact weekly (or monthly) summary; makes reviews cheap to write
# when = "fri 17:45"
# covers = "this-week"       # this-week | last-week | this-month | last-month
'''


class ConfigError(Exception):
    pass


@dataclass
class Task:
    name: str
    do: str
    via: str = ""
    limits: str = ""
    repos: list[str] = field(default_factory=list)
    when: str = "manual"
    agent: str | None = None
    cron: str | None = None
    approval: str = "auto"
    requires: list[str] = field(default_factory=list)
    timeout: int | None = None


@dataclass
class Wrapup:
    when: str = "manual"
    covers: str = "today"
    scan: list[str] = field(default_factory=list)
    ask_user: bool = False
    notify: str = ""
    cron: str | None = None


@dataclass
class Digest:
    when: str = "manual"
    notify: str = ""
    cron: str | None = None


@dataclass
class Rollup:
    when: str = "manual"
    covers: str = "this-week"
    cron: str | None = None


@dataclass
class Config:
    path: Path
    data_dir: Path
    agent: str
    tasks: dict[str, Task]
    wrapup: Wrapup | None
    digest: Digest | None = None
    rollup: Rollup | None = None
    timeout: int = 3600
    nudge_days: int = 7

    @property
    def journal_dir(self) -> Path:
        return self.data_dir / "journal"

    @property
    def tracks_dir(self) -> Path:
        return self.data_dir / "tracks"

    @property
    def rollups_dir(self) -> Path:
        return self.data_dir / "rollups"

    @property
    def reports_dir(self) -> Path:
        return self.data_dir / "reports"


def find_config(explicit: str | None = None) -> Path:
    candidates = [explicit, os.environ.get("AYD_CONFIG"), "ayd.toml", "~/.config/ayd/ayd.toml"]
    for c in candidates:
        if not c:
            continue
        p = Path(c).expanduser()
        if p.is_file():
            return p.resolve()
        if c is explicit:
            raise ConfigError(f"config not found: {c}")
    raise ConfigError("no config found (use --config, $AYD_CONFIG, ./ayd.toml; create one with `ayd init`)")


def _check_keys(section: str, data: dict, allowed: set[str]) -> None:
    extra = set(data) - allowed
    if extra:
        raise ConfigError(f"[{section}] unknown key(s): {', '.join(sorted(extra))} (allowed: {', '.join(sorted(allowed))})")


def _str(section: str, data: dict, key: str, default: str = "") -> str:
    v = data.get(key, default)
    if not isinstance(v, str):
        raise ConfigError(f"[{section}] {key} must be a string")
    return v.strip()


def _strlist(section: str, data: dict, key: str) -> list[str]:
    v = data.get(key, [])
    if isinstance(v, str):
        v = [v]
    if not isinstance(v, list) or not all(isinstance(i, str) for i in v):
        raise ConfigError(f"[{section}] {key} must be a list of strings")
    return v


def _cron(section: str, when: str) -> str | None:
    try:
        return parse_when(when)
    except ValueError as e:
        raise ConfigError(f"[{section}] when: {e}") from None


def _duration(section: str, data: dict, key: str) -> int | None:
    v = _str(section, data, key)
    if not v:
        return None
    try:
        return parse_duration(v)
    except ValueError as e:
        raise ConfigError(f"[{section}] {key}: {e}") from None


def load(path: Path) -> Config:
    try:
        raw = tomllib.loads(path.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path}: invalid TOML: {e}") from None
    _check_keys("top level", raw, {"ayd", "tasks", "wrapup", "digest", "rollup"})

    ayd = raw.get("ayd", {})
    _check_keys("ayd", ayd, {"data_dir", "agent", "timeout", "nudge_days"})
    data_dir = Path(_str("ayd", ayd, "data_dir", "./ayd-data")).expanduser()
    if not data_dir.is_absolute():
        data_dir = path.parent / data_dir
    agent = _str("ayd", ayd, "agent", DEFAULT_AGENT) or DEFAULT_AGENT
    timeout = _duration("ayd", ayd, "timeout") or 3600
    nudge = ayd.get("nudge_days", 7)
    if not isinstance(nudge, int) or isinstance(nudge, bool) or nudge < 0:
        raise ConfigError("[ayd] nudge_days must be a non-negative integer")

    tasks: dict[str, Task] = {}
    for name, t in raw.get("tasks", {}).items():
        sec = f"tasks.{name}"
        if not NAME_RE.match(name) or name in ("wrapup", "digest", "rollup", "report"):
            raise ConfigError(f"[{sec}] invalid task name (lowercase letters/digits/-/_; wrapup/digest/rollup/report are reserved)")
        if not isinstance(t, dict):
            raise ConfigError(f"[{sec}] must be a table")
        _check_keys(sec, t, {"do", "via", "limits", "repos", "when", "agent", "approval", "requires", "timeout"})
        do = _str(sec, t, "do")
        if not do:
            raise ConfigError(f"[{sec}] 'do' is required")
        when = _str(sec, t, "when", "manual") or "manual"
        approval = _str(sec, t, "approval", "auto") or "auto"
        if approval not in ("auto", "ask"):
            raise ConfigError(f"[{sec}] approval must be 'auto' or 'ask'")
        tasks[name] = Task(
            name=name,
            do=do,
            via=_str(sec, t, "via"),
            limits=_str(sec, t, "limits"),
            repos=_strlist(sec, t, "repos"),
            when=when,
            agent=_str(sec, t, "agent") or None,
            cron=_cron(sec, when),
            approval=approval,
            requires=_strlist(sec, t, "requires"),
            timeout=_duration(sec, t, "timeout"),
        )
    for t in tasks.values():
        for r in t.requires:
            m = REQ_RE.match(r)
            if not m:
                raise ConfigError(f"[tasks.{t.name}] bad requirement {r!r} (use name, ran:name, no-questions:name, no-pending:name)")
            if m.group(2) not in tasks and m.group(2) != "wrapup":
                raise ConfigError(f"[tasks.{t.name}] requirement {r!r} names unknown task")
            if m.group(2) == t.name:
                raise ConfigError(f"[tasks.{t.name}] requirement {r!r} refers to itself")

    wrapup = None
    if "wrapup" in raw:
        w = raw["wrapup"]
        _check_keys("wrapup", w, {"when", "covers", "scan", "ask_user", "notify"})
        covers = _str("wrapup", w, "covers", "today") or "today"
        if covers not in ("today", "yesterday"):
            raise ConfigError("[wrapup] covers must be 'today' or 'yesterday'")
        ask = w.get("ask_user", False)
        if not isinstance(ask, bool):
            raise ConfigError("[wrapup] ask_user must be true or false")
        when = _str("wrapup", w, "when", "manual") or "manual"
        wrapup = Wrapup(
            when=when,
            covers=covers,
            scan=_strlist("wrapup", w, "scan"),
            ask_user=ask,
            notify=_str("wrapup", w, "notify"),
            cron=_cron("wrapup", when),
        )

    digest = None
    if "digest" in raw:
        d = raw["digest"]
        _check_keys("digest", d, {"when", "notify"})
        when = _str("digest", d, "when", "manual") or "manual"
        digest = Digest(when=when, notify=_str("digest", d, "notify"), cron=_cron("digest", when))

    rollup = None
    if "rollup" in raw:
        r = raw["rollup"]
        _check_keys("rollup", r, {"when", "covers"})
        covers = _str("rollup", r, "covers", "this-week") or "this-week"
        if covers not in ROLLUP_COVERS:
            raise ConfigError(f"[rollup] covers must be one of {', '.join(ROLLUP_COVERS)}")
        when = _str("rollup", r, "when", "manual") or "manual"
        rollup = Rollup(when=when, covers=covers, cron=_cron("rollup", when))

    return Config(path=path, data_dir=data_dir, agent=agent, tasks=tasks, wrapup=wrapup,
                  digest=digest, rollup=rollup, timeout=timeout, nudge_days=nudge)
