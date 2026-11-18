"""Period specs: 2026, 2026-Q4, 2026-H1, 2026-11, 2026-W47, this-/last-(week|month|quarter|half|year)."""

from __future__ import annotations

import calendar
import re
from dataclasses import dataclass
from datetime import date, timedelta

UNITS = ("week", "month", "quarter", "half", "year")


@dataclass(frozen=True)
class Period:
    label: str
    start: date
    end: date  # inclusive

    def days(self):
        d = self.start
        while d <= self.end:
            yield d
            d += timedelta(days=1)

    def contains(self, d: date) -> bool:
        return self.start <= d <= self.end


def _month_end(y: int, m: int) -> date:
    return date(y, m, calendar.monthrange(y, m)[1])


def _span(y: int, m1: int, m2: int) -> tuple[date, date]:
    return date(y, m1, 1), _month_end(y, m2)


def containing(unit: str, d: date) -> Period:
    if unit == "week":
        y, w, _ = d.isocalendar()
        s = date.fromisocalendar(y, w, 1)
        return Period(f"{y}-W{w:02d}", s, s + timedelta(days=6))
    if unit == "month":
        return Period(f"{d.year}-{d.month:02d}", date(d.year, d.month, 1), _month_end(d.year, d.month))
    if unit == "quarter":
        q = (d.month - 1) // 3
        s, e = _span(d.year, q * 3 + 1, q * 3 + 3)
        return Period(f"{d.year}-Q{q + 1}", s, e)
    if unit == "half":
        h = (d.month - 1) // 6
        s, e = _span(d.year, h * 6 + 1, h * 6 + 6)
        return Period(f"{d.year}-H{h + 1}", s, e)
    if unit == "year":
        return Period(str(d.year), date(d.year, 1, 1), date(d.year, 12, 31))
    raise ValueError(f"unknown unit {unit!r}")


def parse(spec: str, today: date) -> Period:
    s = spec.strip()
    m = re.fullmatch(r"(this|last)-(week|month|quarter|half|year)", s.lower())
    if m:
        cur = containing(m.group(2), today)
        return cur if m.group(1) == "this" else containing(m.group(2), cur.start - timedelta(days=1))
    try:
        if m := re.fullmatch(r"(\d{4})", s):
            return containing("year", date(int(m.group(1)), 1, 1))
        if m := re.fullmatch(r"(\d{4})-[Qq]([1-4])", s):
            return containing("quarter", date(int(m.group(1)), int(m.group(2)) * 3 - 2, 1))
        if m := re.fullmatch(r"(\d{4})-[Hh]([12])", s):
            return containing("half", date(int(m.group(1)), int(m.group(2)) * 6 - 5, 1))
        if m := re.fullmatch(r"(\d{4})-(\d{2})", s):
            return containing("month", date(int(m.group(1)), int(m.group(2)), 1))
        if m := re.fullmatch(r"(\d{4})-[Ww](\d{2})", s):
            return containing("week", date.fromisocalendar(int(m.group(1)), int(m.group(2)), 1))
    except ValueError:
        pass
    raise ValueError(f"bad period {spec!r}; use 2026, 2026-Q4, 2026-H1, 2026-11, 2026-W47, or this-/last-week|month|quarter|half|year")


def custom(start: date, end: date) -> Period:
    if end < start:
        raise ValueError("--to is before --from")
    return Period(f"{start}..{end}", start, end)
