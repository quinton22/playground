---
name: ayd-setup
description: Interview the user and write or update their ayd.toml (automate-your-day config) - which daily tasks to automate, via which connectors, with what hard limits, how often, and what the end-of-day wrapup scans. Use when the user wants to set up, change, or review their ayd automation.
---

# ayd setup

Goal: produce a short, human-readable `ayd.toml` (see `examples/ayd.toml` in the ayd project, or run `ayd init`).

## Interview (ask in small groups, skip what is already known)

For each recurring piece of work the user wants automated:
1. **do** - one sentence: what the agent does.
2. **via** - which connector/tool (Outlook, Atlassian/Jira, Slack, GitHub, ...). Check which connectors are actually available to the agent; if one is missing, say so.
3. **limits** - the ceiling on autonomy. Ask explicitly: "What must the agent never do?" Write it as imperatives ("Drafts only. Never send."). If the user gives none, propose a conservative default (read-only / drafts / branches) and confirm.
4. **repos** - paths of repositories, if coding.
5. **when** - `manual`, `every 30m`, `every 2h`, `daily 09:00`, `weekdays 09:00`, `mon,wed 08:00`.

Then the wrapup:
- **when** it runs (end of day, or next morning) and **covers** `today` / `yesterday`.
- **scan**: which sources to check for work the user did themselves (sent mail, Slack, meetings, commits). Empty list = scan nothing.
- **ask_user**: whether to also prompt the user for extra items; **notify** command if scheduled with no terminal.

Also: **data_dir** (where journal/ and tracks/ live; suggest somewhere backed up, outside code repos) and **agent** (the command that takes a prompt on stdin, default `claude -p`).

## Write and verify
1. Write `ayd.toml`, keeping text terse; one task per `[tasks.<name>]`.
2. Run `ayd check`; fix any error it reports.
3. Show the user the final config and the cron schedule (`ayd schedule`). Only run `ayd schedule --install` if they agree.
4. Remind them: limits are instructions to the agent. For hard guarantees, also restrict the connector's own permissions (e.g. a read/draft-only token).
