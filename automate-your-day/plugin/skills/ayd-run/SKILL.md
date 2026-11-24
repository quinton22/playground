---
name: ayd-run
description: Run a configured automate-your-day (ayd) task interactively - read the briefing (previous day's journal plus active long-running tracks), do the work within the configured limits, and log outcomes and next steps. Use when the user asks to run an ayd task or "do my daily work".
---

# ayd run

0. If the user did not name a task, run `ayd brief` (an overview for choosing only; it has no limits) and ask which to run. Never do task work from the overview.
1. Run `ayd start <task>`. If it exits non-zero (prerequisites unmet, or the task is already running) STOP and tell the user why; do not work around it. Otherwise read its output fully; it already contains the task, its HARD limits, the previous journal, today's journal, and active tracks. Do not read other journal files unless a line points to them.
2. Do the work using the connectors named in `via`. Stay inside `limits`; if something would exceed them, skip it and log a question instead.
3. Log as you go with `ayd log <task> "<terse text>"`:
   - `-k A` what you did (default), `-k N` the concrete next step for anything unfinished, `-k Q` a question for the user.
   - Add `--track <slug>` for long-running or deadline work (create with `ayd track new <slug> --title ... --due YYYY-MM-DD`).
4. If unsure what the next step should be or what the user wants, **ask the user now** and also log a `Q`.
5. Run `ayd finish <task>` (or `ayd finish <task> --failed --note "..."` if you could not complete it) so the run is recorded and later tasks' `requires` can see it.
6. Finish with a 2-3 line summary to the user: done, next steps, open questions.

Entries are for a future agent, not for people: terse, include ids/links/branch names needed to resume.
