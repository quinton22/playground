---
name: ayd-report
description: Write a quarterly/annual review, promotion packet, accomplishment list, or answers to end-of-year review questions from the automate-your-day (ayd) record. Use when the user asks for a self-review, performance review, promo packet/case, brag document, or to answer review questions based on what they did.
---

# ayd report

The record (journal, tracks, rollups) is the only evidence. Never invent facts.

1. **Clarify** (skip what is known): which kind - `review`, `promo` (target role/level), `answers` (get the questions: paste or file), `brag`, or a free-form `ask`; the period (`2026-Q4`, `last-quarter`, `2026`, `2026-H1`, or custom `--from/--to`); audience and tone.
2. **Shrink the evidence first** if the period is long and rollups are missing: `ayd rollup run --period <2026-10>` (or weekly) for older months. `ayd report ... --dry-run` prints the evidence size on stderr.
3. **Get the prompt + evidence:** `ayd report <kind> --period <P> [--target ...] [--note ...] [--questions FILE] --dry-run`. Read it fully, then write the document yourself following its GROUND RULES (cite dates, `[NEEDS INPUT: ...]` for gaps, "Notes for the author" at the end). Or let the configured agent do it unattended: drop `--dry-run`; the result is saved under `<data_dir>/reports/`.
4. **Resolve gaps with the user.** For each `[NEEDS INPUT]`, ask, then fold in the answer. Record real answers as lasting evidence: `ayd add "<what>" --win --date <D>`.
5. Offer to save the final text to the user's chosen file. Point out any substantially AI-assisted (A) work so they can describe it accurately.
