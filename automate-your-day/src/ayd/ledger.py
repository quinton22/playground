"""Id'd items that need a human: questions (q1..) and proposed actions awaiting approval (a1..).

File lines: id|status|YYYY-MM-DD|task|text|note
questions: O open, A answered, X closed.   actions: P pending, A approved, R rejected, X closed.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from .config import Config
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

    def all(self) -> list[Item]:
        if not self.path.exists():
            return []
        items = []
        for line in self.path.read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                p = line.split("|", 5)
                if len(p) == 6:
                    items.append(Item(*p))
        return items

    def _save(self, items: list[Item]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        head = f"#ayd1 ledger {self.prefix}: id|status|date|task|text|note\n"
        self.path.write_text(head + "".join(i.line() + "\n" for i in items), encoding="utf-8")

    def add(self, task: str, text: str, now: datetime) -> str:
        items = self.all()
        n = max((int(i.id[len(self.prefix):]) for i in items), default=0) + 1
        item = Item(f"{self.prefix}{n}", self.start, now.date().isoformat(), clean(task), clean(text))
        self._save(items + [item])
        return item.id

    def get(self, id_: str) -> Item | None:
        return next((i for i in self.all() if i.id == id_), None)

    def set_status(self, id_: str, status: str, note: str = "") -> None:
        items = self.all()
        for i in items:
            if i.id == id_:
                i.status = status
                if note:
                    i.note = clean(note)
                self._save(items)
                return
        raise KeyError(id_)

    def by_status(self, *statuses: str, task: str | None = None) -> list[Item]:
        return [i for i in self.all() if i.status in statuses and (task is None or i.task == task)]

    def purge_closed(self, before: date) -> int:
        items = self.all()
        keep = [i for i in items if not (i.status == "X" and i.date < before.isoformat())]
        if len(keep) != len(items):
            self._save(keep)
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
