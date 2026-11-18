"""Parse human-readable `when` strings into cron expressions and manage a crontab block."""

from __future__ import annotations

import re
import shlex

DOW = {"sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6}
BEGIN = "# BEGIN ayd (managed by `ayd schedule`)"
END = "# END ayd"

WHEN_HELP = (
    '"manual" | "every 30m" | "every 2h" | "daily 09:00" | "weekdays 17:30" | "mon,wed,fri 08:00"'
)


def parse_duration(value: str) -> int:
    """'90s' | '30m' | '2h' -> seconds. Raises ValueError."""
    m = re.fullmatch(r"(\d+)([smh])", value.strip().lower())
    if not m or int(m.group(1)) == 0:
        raise ValueError(f"bad duration {value!r} (use e.g. 90s, 30m, 2h)")
    return int(m.group(1)) * {"s": 1, "m": 60, "h": 3600}[m.group(2)]


def parse_when(value: str) -> str | None:
    """Return a 5-field cron expression, or None for manual tasks. Raises ValueError."""
    s = value.strip().lower()
    if s in ("", "manual"):
        return None
    m = re.fullmatch(r"every (\d+)([mh])", s)
    if m:
        n, unit = int(m.group(1)), m.group(2)
        if unit == "m" and 1 <= n <= 59:
            return f"*/{n} * * * *"
        if unit == "h" and 1 <= n <= 23:
            return f"0 */{n} * * *"
        raise ValueError(f"bad interval {value!r} (1-59 minutes or 1-23 hours)")
    m = re.fullmatch(r"(daily|weekdays|[a-z]{3}(?:,[a-z]{3})*) (\d{1,2}):(\d{2})", s)
    if m:
        days, hh, mm = m.group(1), int(m.group(2)), int(m.group(3))
        if hh > 23 or mm > 59:
            raise ValueError(f"bad time in {value!r}")
        if days == "daily":
            dow = "*"
        elif days == "weekdays":
            dow = "1-5"
        else:
            names = days.split(",")
            if any(n not in DOW for n in names):
                raise ValueError(f"bad weekday in {value!r}")
            dow = ",".join(str(DOW[n]) for n in names)
        return f"{mm} {hh} * * {dow}"
    raise ValueError(f"cannot parse {value!r}; use one of: {WHEN_HELP}")


def crontab_block(entries: list[tuple[str, str]], config_path: str, ayd_bin: str = "ayd") -> str:
    """entries: (cron_expr, subcommand) e.g. ("0 9 * * 1-5", "run email")."""
    lines = [BEGIN]
    for cron, sub in entries:
        lines.append(f"{cron} {shlex.quote(ayd_bin)} --config {shlex.quote(config_path)} {sub}")
    lines.append(END)
    return "\n".join(lines) + "\n"


def strip_block(existing: str) -> str:
    out, skipping = [], False
    for line in existing.splitlines():
        if line.startswith("# BEGIN ayd"):
            skipping = True
            continue
        if skipping and line.startswith("# END ayd"):
            skipping = False
            continue
        if not skipping:
            out.append(line)
    return "\n".join(out).rstrip("\n") + ("\n" if out else "")


def merge_crontab(existing: str, block: str) -> str:
    base = strip_block(existing)
    return (base + "\n" if base else "") + block
