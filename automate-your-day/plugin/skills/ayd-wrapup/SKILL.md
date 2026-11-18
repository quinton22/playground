---
name: ayd-wrapup
description: Run the automate-your-day (ayd) wrapup - scan the configured sources for work the user did themselves (emails sent, Slack, meetings), ask the user for any extra items, record them in the journal, and set next steps. Use at end of day / start of next day, or when the user says "wrap up my day".
---

# ayd wrapup

1. Run `ayd brief wrapup` and read it. It names the day being covered, the **only** sources you may scan, and whether to ask the user.
2. Scan each listed source, read-only, for the user's activity on that day. Never send, post, or modify anything. Log each item: `ayd log wrapup "<terse text>" -k U --date <day>`. Merge trivial items; skip anything already in the journal.
3. If the brief says to ask the user: ask "Anything else you did that I would not see?" and log each answer with `ayd add "<text>" --date <day>`.
4. Review that day's journal and the active tracks. For each unfinished item log the concrete next step (`-k N --date <day>`); if unsure, ask the user and log a `Q`. Update tracks (`ayd track set <slug> status done`, or log progress with `--track`).
5. Give the user a short summary: what was recorded, next steps, open questions.
