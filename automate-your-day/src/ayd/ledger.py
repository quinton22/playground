"""Id'd items that need a human: questions (q1..) and proposed actions awaiting approval (a1..).

File lines: id|status|YYYY-MM-DD|task|text|note   (plus a `#hw N` line: highest id ever issued, so ids are never reused)
questions: O open, A answered, X closed.   actions: P pending, A approved, R rejected, X closed.
All read-modify-write operations hold an interprocess lock and replace the file atomically.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from .config import Config
from .fsutil import atomic_write, file_lock
from .journal import clean


@dataclass
class Item:
    id: str
    status: str
    date: str
    task: str
    text: str
    note: str = ""

    def line(self) -> str:
        return f"{self.id}|{self.status}|{self.date}|{self.task}|{self.text}|{self.note}"


class Ledger:
    def __init__(self, path: Path, prefix: str, start: str):
        self.path, self.prefix, self.start = path, prefix, start
        self._lock = path.with_name(path.name + ".lock")

    def _read(self) -> tuple[list[Item], int]:
        items, hw = [], 0
        if self.path.exists():
            for line in self.path.read_text(encoding="utf-8").splitlines():
                if line.startswith("#hw "):
                    hw = int(line[4:])
                elif line and not line.startswith("#"):
                    p = line.split("|", 5)
                    if len(p) == 6:
                        items.append(Item(*p))
        return items, hw

    def _high(self, items: list[Item], hw: int) -> int:
        return max([hw] + [int(i.id[len(self.prefix):]) for i in items])

    def _save(self, items: list[Item], hw: int) -> None:
        head = f"#ayd1 ledger {self.prefix}: id|status|date|task|text|note\n#hw {self._high(items, hw)}\n"
        atomic_write(self.path, head + "".join(i.line() + "\n" for i in items))

    def all(self) -> list[Item]:
        return self._read()[0]

    def add(self, task: str, text: str, now: datetime) -> str:
        with file_lock(self._lock):
            items, hw = self._read()
            item = Item(f"{self.prefix}{self._high(items, hw) + 1}", self.start, now.date().isoformat(), clean(task), clean(text))
            self._save(items + [item], hw)
        return item.id

    def get(self, id_: str) -> Item | None:
        return next((i for i in self.all() if i.id == id_), None)

    def set_status(self, id_: str, status: str, note: str = "") -> None:
        with file_lock(self._lock):
            items, hw = self._read()
            for i in items:
                if i.id == id_:
                    i.status = status
                    if note:
                        i.note = clean(note)
                    self._save(items, hw)
                    return
        raise KeyError(id_)

    def by_status(self, *statuses: str, task: str | None = None) -> list[Item]:
        return [i for i in self.all() if i.status in statuses and (task is None or i.task == task)]

    def purge_closed(self, before: date) -> int:
        with file_lock(self._lock):
            items, hw = self._read()
            keep = [i for i in items if not (i.status == "X" and i.date < before.isoformat())]
            if len(keep) != len(items):
                self._save(keep, self._high(items, hw))  # high-water mark survives the purge
            return len(items) - len(keep)


def questions(cfg: Config) -> Ledger:
    return Ledger(cfg.data_dir / "questions.ayd", "q", "O")


def actions(cfg: Config) -> Ledger:
    return Ledger(cfg.data_dir / "queue.ayd", "a", "P")


def find(cfg: Config, id_: str) -> tuple[Ledger, Item]:
    for led in (questions(cfg), actions(cfg)):
        if id_.startswith(led.prefix):
            item = led.get(id_)
            if item:
                return led, item
    raise KeyError(f"no such item: {id_}")
