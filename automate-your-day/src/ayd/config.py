"""Load and validate the user's ayd.toml."""

from __future__ import annotations

import os
import re
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

from .schedule import parse_when

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
DEFAULT_AGENT = "claude -p"

STARTER = '''\
# ayd config. Keep it short: each task says WHAT, VIA what, and the HARD LIMITS.
[ayd]
data_dir = "./ayd-data"      # journal/ (one file per day) and tracks/ live here
agent = "claude -p"          # command that receives the prompt on stdin

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

[wrapup]
when = "weekdays 17:30"
covers = "today"             # today | yesterday (use yesterday if wrapup runs next morning)
scan = ["sent email (Outlook)", "Slack messages I sent", "calendar meetings attended"]
ask_user = true              # also ask me for extra items I did
# notify = "notify-send ayd \\"$AYD_MESSAGE\\""   # run when asking but no terminal is attached
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


@dataclass
class Wrapup:
    when: str = "manual"
    covers: str = "today"
    scan: list[str] = field(default_factory=list)
    ask_user: bool = False
    notify: str = ""
    cron: str | None = None


@dataclass
class Config:
    path: Path
    data_dir: Path
    agent: str
    tasks: dict[str, Task]
    wrapup: Wrapup | None

    @property
    def journal_dir(self) -> Path:
        return self.data_dir / "journal"

    @property
    def tracks_dir(self) -> Path:
        return self.data_dir / "tracks"


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
    if not isinstance(v, list) or not all(isinstance(i, str) for i in v):
        raise ConfigError(f"[{section}] {key} must be a list of strings")
    return v


def _cron(section: str, when: str) -> str | None:
    try:
        return parse_when(when)
    except ValueError as e:
        raise ConfigError(f"[{section}] when: {e}") from None


def load(path: Path) -> Config:
    try:
        raw = tomllib.loads(path.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path}: invalid TOML: {e}") from None
    _check_keys("top level", raw, {"ayd", "tasks", "wrapup"})

    ayd = raw.get("ayd", {})
    _check_keys("ayd", ayd, {"data_dir", "agent"})
    data_dir = Path(_str("ayd", ayd, "data_dir", "./ayd-data")).expanduser()
    if not data_dir.is_absolute():
        data_dir = path.parent / data_dir
    agent = _str("ayd", ayd, "agent", DEFAULT_AGENT) or DEFAULT_AGENT

    tasks: dict[str, Task] = {}
    for name, t in raw.get("tasks", {}).items():
        sec = f"tasks.{name}"
        if not NAME_RE.match(name) or name == "wrapup":
            raise ConfigError(f"[{sec}] invalid task name (lowercase letters/digits/-/_; 'wrapup' is reserved)")
        if not isinstance(t, dict):
            raise ConfigError(f"[{sec}] must be a table")
        _check_keys(sec, t, {"do", "via", "limits", "repos", "when", "agent"})
        do = _str(sec, t, "do")
        if not do:
            raise ConfigError(f"[{sec}] 'do' is required")
        when = _str(sec, t, "when", "manual") or "manual"
        tasks[name] = Task(
            name=name,
            do=do,
            via=_str(sec, t, "via"),
            limits=_str(sec, t, "limits"),
            repos=_strlist(sec, t, "repos"),
            when=when,
            agent=_str(sec, t, "agent") or None,
            cron=_cron(sec, when),
        )

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

    return Config(path=path, data_dir=data_dir, agent=agent, tasks=tasks, wrapup=wrapup)
