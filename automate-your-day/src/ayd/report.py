"""Prompts for rollups (periodic summaries) and reports (reviews, promo packets, review-question answers)."""

from __future__ import annotations

from datetime import date

from . import history
from .config import Config
from .periods import Period

REPORT_KINDS = ("review", "promo", "answers", "brag", "ask")
DEFAULT_PERIOD = dict(review="last-quarter", promo="last-year", answers="last-year", brag="this-year", ask="this-year")

KIND_HELP = {
    "review": "self-review / quarterly review",
    "promo": "promotion packet",
    "answers": "answers to review questions you supply",
    "brag": "resume-style accomplishment list",
    "ask": "any free-form request, grounded in the record",
}

FORMAT = """\
EVIDENCE FORMAT: journal `kind|HH:MM|task|text` under `## date` headings; rollups `kind|text`; track entries `date|kind|text`.
 A = done by the user's AI assistant on their behalf, U = done by the user directly, W/H = notable accomplishment or impact,
 M = metric, N = planned next step, C = carry-over/context, Q = question."""

GROUND_RULES = """\
GROUND RULES
- Use ONLY the evidence below. Cite after each claim as [YYYY-MM-DD] or [track:slug] (rollup lines: [rollup:label]).
- Never invent metrics, names, titles, scope, or outcomes. If a good answer needs facts you do not have, write
  [NEEDS INPUT: what is missing] so the author can fill it in. Do not pad.
- Prefer W/H/M lines and tracks for impact. Routine noise (empty triage runs, failed-run notes) is not an accomplishment.
- A lines were done by the author's AI assistant; present the outcome as the author's work, but do not claim more than was logged.
  End with a short "Notes for the author" section: gaps, [NEEDS INPUT] items, and any substantially AI-assisted work they may
  want to describe accurately.
- Output only the finished markdown document: no preamble, no commentary outside the document."""

GOALS = {
    "review": """\
Write a self-review for the period. Sections: Summary (3-5 sentences); Key accomplishments (grouped by theme; each with
what you did, the impact, and evidence); Collaboration and communication; Challenges and learnings; Goals for next period
(derive from N lines, active tracks and deadlines).""",
    "promo": """\
Write a promotion packet{target}. Sections: Summary of the case; Scope and level evidence (map accomplishments to scope,
impact, leadership, craft, and collaboration, strongest first); Top 5-7 projects (problem, action, result, evidence);
Sustained performance timeline by month; Gaps to address before submitting.""",
    "answers": """\
Answer each question in QUESTIONS in order, in first person, restating each question as a heading. Give specific examples
with dates and outcomes; aim for 100-250 words per answer unless a question states a limit.""",
    "brag": """\
Write a resume-style list of accomplishments grouped by theme, most impactful first. One bullet each: strong verb, what,
quantified outcome when the evidence has numbers. No more than ~25 bullets.""",
    "ask": "Fulfil the REQUEST below.",
}


def build_report(cfg: Config, kind: str, period: Period, *, questions: str | None = None, ask: str | None = None,
                 target: str | None = None, note: str | None = None) -> tuple[str, dict]:
    if kind not in REPORT_KINDS:
        raise ValueError(f"report kind must be one of {', '.join(REPORT_KINDS)}")
    if kind == "answers" and not questions:
        raise ValueError("answers needs --questions FILE")
    if kind == "ask" and not ask:
        raise ValueError("ask needs --ask TEXT")
    evidence, info = history.pack(cfg, period)
    goal = GOALS[kind].format(target=f" for {target}" if target else "") if kind == "promo" else GOALS[kind]
    parts = [
        f"# ayd report: {kind} for {period.label} ({period.start}..{period.end})",
        goal,
    ]
    if target and kind != "promo":
        parts.append(f"TARGET: {target}")
    if note:
        parts.append(f"AUTHOR NOTES (tone/audience/context): {note}")
    if questions:
        parts.append("QUESTIONS\n" + questions.strip())
    if ask:
        parts.append("REQUEST\n" + ask.strip())
    parts += [GROUND_RULES, FORMAT, "EVIDENCE\n" + evidence]
    return "\n\n".join(parts) + "\n", info


ROLLUP_RULES = """\
Condense the evidence into a rollup for future readers (another AI, later). Output ONLY lines of the form `kind|text`:
 H|accomplishment with its impact and the date(s) it happened   M|a metric or number   C|carry-over: unfinished work, decisions, context a later period needs
Rules: 5-15 lines total, each under 200 characters. Keep every W line (as H). Merge routine items, drop failed-run noise and
duplicates. Never invent facts. No headings, no prose, no markdown."""


def build_rollup(cfg: Config, period: Period) -> tuple[str, dict]:
    evidence, info = history.pack(cfg, period, exclude=period.label)
    prompt = "\n\n".join([
        f"# ayd rollup for {period.label} ({period.start}..{period.end})",
        ROLLUP_RULES,
        FORMAT,
        "EVIDENCE\n" + evidence,
    ]) + "\n"
    return prompt, info


def parse_rollup_output(out: str) -> list[str]:
    from .journal import clean
    lines = []
    for raw in out.splitlines():
        s = raw.strip().lstrip("-* ").strip()
        if len(s) > 2 and s[0] in history.ROLLUP_KINDS and s[1] == "|":
            lines.append(f"{s[0]}|{clean(s[2:])}")
    return lines
