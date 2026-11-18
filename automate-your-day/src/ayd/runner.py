"""Run the agent with an overlap lock, timeout, run history, and task requirements."""

from __future__ import annotations

import os
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from . import journal, ledger
from .config import REQ_RE, Config, Task

HEAD = "#ayd1 runs: date|HH:MM|task|status|secs|rc|tok_in~|tok_out~|note  (tokens are chars/4 estimates)\n"


@dataclass
class Result:
    status: str  # ok | failed | timeout | skipped
    rc: int = 0
    out: str = ""

    @property
    def exit_code(self) -> int:
        return 0 if self.status in ("ok", "skipped") else (self.rc or 1)


@dataclass
class Run:
    date: date
    time: str
    task: str
    status: str
    secs: int
    rc: int
    tin: int
    tout: int
    note: str


def runs_path(cfg: Config) -> Path:
    return cfg.data_dir / "runs.ayd"


def record(cfg: Config, now: datetime, key: str, status: str, secs: float = 0, rc: int = 0,
           tin: int = 0, tout: int = 0, note: str = "") -> None:
    p = runs_path(cfg)
    p.parent.mkdir(parents=True, exist_ok=True)
    new = not p.exists()
    with p.open("a", encoding="utf-8") as f:
        if new:
            f.write(HEAD)
        f.write(f"{now:%Y-%m-%d}|{now:%H:%M}|{journal.clean(key)}|{status}|{secs:.0f}|{rc}|{tin}|{tout}|{journal.clean(note)}\n")


def read_runs(cfg: Config) -> list[Run]:
    p = runs_path(cfg)
    if not p.exists():
        return []
    out = []
    for line in p.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        f = line.split("|", 8)
        if len(f) == 9:
            out.append(Run(date.fromisoformat(f[0]), f[1], f[2], f[3], int(f[4]), int(f[5]), int(f[6]), int(f[7]), f[8]))
    return out


def unmet(cfg: Config, task: Task, now: datetime) -> str | None:
    """Reason this task should not run now, or None."""
    runs = read_runs(cfg)
    for r in task.requires:
        m = REQ_RE.match(r)
        kind, name = (m.group(1) or "ran"), m.group(2)
        if kind == "ran":
            if not any(x.task == name and x.status == "ok" and x.date == now.date() for x in runs):
                return f"requires '{name}' to have run successfully today"
        elif kind == "no-questions":
            if ledger.questions(cfg).by_status("O", task=name):
                return f"'{name}' has open questions"
        elif kind == "no-pending":
            if ledger.actions(cfg).by_status("P", task=name):
                return f"'{name}' has actions awaiting approval"
    return None


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def acquire(cfg: Config, key: str, stale_after: float) -> Path | None:
    p = cfg.data_dir / "locks" / f"{key}.lock"
    p.parent.mkdir(parents=True, exist_ok=True)
    for _ in range(2):
        try:
            fd = os.open(p, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            try:
                pid_s, t_s = p.read_text().split()
                live = _pid_alive(int(pid_s)) and time.time() - float(t_s) < stale_after
            except (ValueError, OSError):
                live = False
            if live:
                return None
            p.unlink(missing_ok=True)
            continue
        with os.fdopen(fd, "w") as f:
            f.write(f"{os.getpid()} {time.time()}")
        return p
    return None


def run_agent(cfg: Config, key: str, agent: str, prompt: str, now: datetime, timeout: int | None = None) -> Result:
    timeout = timeout or cfg.timeout
    lock = acquire(cfg, key, stale_after=timeout * 2)
    if lock is None:
        record(cfg, now, key, "skipped", note="already running")
        print(f"ayd: {key} is already running; skipped", file=sys.stderr)
        return Result("skipped")
    env = {**os.environ, "AYD_CONFIG": str(cfg.path)}
    t0, status, rc, out = time.monotonic(), "ok", 0, ""
    try:
        p = subprocess.run(shlex.split(agent), input=prompt, text=True, env=env, stdout=subprocess.PIPE, timeout=timeout)
        rc, out = p.returncode, p.stdout or ""
        if rc:
            status = "failed"
    except subprocess.TimeoutExpired as e:
        status, rc = "timeout", 124
        o = e.stdout or ""
        out = o.decode(errors="replace") if isinstance(o, bytes) else o
    except FileNotFoundError:
        print(f"ayd: agent command not found: {agent}", file=sys.stderr)
        status, rc = "failed", 127
    finally:
        lock.unlink(missing_ok=True)
    if out:
        sys.stdout.write(out)
        sys.stdout.flush()
    record(cfg, now, key, status, time.monotonic() - t0, rc, len(prompt) // 4, len(out) // 4)
    if status != "ok":
        journal.append(cfg, "A", key, f"FAILED ({status}, exit {rc}); retry next run", now)
    return Result(status, rc, out)


def stats(cfg: Config, since: date, task: str | None = None) -> list[dict]:
    rows: dict[str, dict] = {}
    for r in read_runs(cfg):
        if r.date < since or (task and r.task != task):
            continue
        s = rows.setdefault(r.task, dict(task=r.task, runs=0, ok=0, failed=0, skipped=0, secs=0, tin=0, tout=0))
        if r.status == "skipped":
            s["skipped"] += 1
            continue
        s["runs"] += 1
        s["ok" if r.status == "ok" else "failed"] += 1
        s["secs"] += r.secs
        s["tin"] += r.tin
        s["tout"] += r.tout
    return sorted(rows.values(), key=lambda s: -(s["tin"] + s["tout"]))
