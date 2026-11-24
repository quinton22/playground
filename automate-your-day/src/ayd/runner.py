"""Run the agent with an overlap lock, timeout, run history, and task requirements."""

from __future__ import annotations

import os
import shlex
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from . import journal, ledger
from .config import REQ_RE, Config, Task
from .fsutil import file_lock

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


try:
    import fcntl
except ImportError:
    fcntl = None


def _lock_dir(cfg: Config) -> Path:
    return cfg.data_dir / "locks"


def acquire(cfg: Config, key: str):
    """Hold an OS-level lock for `key` for as long as the returned file is open (None if someone else holds it).
    The OS drops it if the process dies, so there is no stale-lock reclaiming and no initialization race."""
    d = _lock_dir(cfg)
    d.mkdir(parents=True, exist_ok=True)
    f = open(d / f"{key}.lock", "a+")
    if fcntl:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            f.close()
            return None
    f.seek(0)
    f.truncate()
    f.write(f"{os.getpid()} {time.time()}")
    f.flush()
    return f


def release(f) -> None:
    try:
        if fcntl:
            fcntl.flock(f, fcntl.LOCK_UN)
    finally:
        f.close()


def _session_path(cfg: Config, key: str) -> Path:
    return _lock_dir(cfg) / f"{key}.session"


def _session_fresh(cfg: Config, key: str) -> float | None:
    """Start time of a live interactive session for `key` (they time out after cfg.timeout), else None."""
    p = _session_path(cfg, key)
    try:
        t = float(p.read_text().strip())
    except (OSError, ValueError):
        return None
    return t if time.time() - t < cfg.timeout else None


def session_start(cfg: Config, key: str) -> str | None:
    """Interactive counterpart of run_agent's lock (an interactive agent is not a process we can hold a lock for).
    Returns a reason string if the task is busy, else records the session start and returns None."""
    _lock_dir(cfg).mkdir(parents=True, exist_ok=True)
    with file_lock(_lock_dir(cfg) / f"{key}.session.lock"):
        held = acquire(cfg, key)
        if held is None:
            return "already running"
        release(held)
        if _session_fresh(cfg, key):
            return "an interactive session is already in progress (finish it with `ayd finish`)"
        _session_path(cfg, key).write_text(str(time.time()))
    return None


def session_finish(cfg: Config, key: str, now: datetime, ok: bool = True, note: str = "") -> None:
    started = _session_fresh(cfg, key)
    _session_path(cfg, key).unlink(missing_ok=True)
    secs = max(0.0, time.time() - started) if started else 0.0
    record(cfg, now, key, "ok" if ok else "failed", secs, 0 if ok else 1, note=note or "interactive")
    if not ok:
        journal.append(cfg, "A", key, f"FAILED (interactive){': ' + note if note else ''}; retry next run", now)


def _kill_group(proc: subprocess.Popen) -> None:
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError, AttributeError):
        proc.kill()


def run_agent(cfg: Config, key: str, agent: str, prompt: str, now: datetime, timeout: int | None = None) -> Result:
    timeout = timeout or cfg.timeout
    lock = acquire(cfg, key)
    if lock is not None and _session_fresh(cfg, key):
        release(lock)
        lock = None
    if lock is None:
        record(cfg, now, key, "skipped", note="already running")
        print(f"ayd: {key} is already running; skipped", file=sys.stderr)
        return Result("skipped")
    env = {**os.environ, "AYD_CONFIG": str(cfg.path)}
    t0, status, rc, out = time.monotonic(), "ok", 0, ""
    try:
        # own session/process group so a timeout can kill everything the agent spawned
        proc = subprocess.Popen(shlex.split(agent), stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
                                env=env, start_new_session=True)
        try:
            out, _ = proc.communicate(prompt, timeout=timeout)
            rc = proc.returncode
            if rc:
                status = "failed"
        except subprocess.TimeoutExpired:
            _kill_group(proc)
            out, _ = proc.communicate()  # reaps the agent
            status, rc = "timeout", 124
        except BaseException:
            _kill_group(proc)
            proc.wait()
            raise
        finally:
            _kill_group(proc)  # also reaps anything the agent left running before the lock is released
    except FileNotFoundError:
        print(f"ayd: agent command not found: {agent}", file=sys.stderr)
        status, rc = "failed", 127
    finally:
        release(lock)
    out = out or ""
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
