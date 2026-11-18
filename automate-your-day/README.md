# automate-your-day (`ayd`)

Config-driven daily work automation for AI agents. You describe, in one short TOML file, **what** to automate, **how**, and **how far** the agent may go. `ayd` runs the agent on a schedule (or on demand), keeps a **compact journal** of everything done, and gives the next run exactly the context it needs: the last journal file plus any active long-running tracks.

It has two parts:

- `ayd` - a zero-dependency Python CLI (briefings, journal, tracks, scheduling, running an agent).
- `plugin/` - a Claude Code plugin with skills: `ayd-setup` (AI-assisted config), `ayd-run`, `ayd-wrapup`. Any other agent can use the CLI directly: `ayd brief <task>` prints everything it needs to know.

## Install

```bash
cd automate-your-day
python -m venv .venv && . .venv/bin/activate
pip install -e '.[dev]'
pytest
```

For Claude Code, add `plugin/` as a plugin (e.g. `claude --plugin-dir ./plugin`), then ask: *"use ayd-setup to create my config"*.

## Config (`ayd.toml`)

Found via `--config`, `$AYD_CONFIG`, `./ayd.toml`, or `~/.config/ayd/ayd.toml`. `ayd init` writes a starter; see `examples/ayd.toml`.

```toml
[ayd]
data_dir = "~/ayd-data"          # journal/ and tracks/ live here (relative = next to config)
agent = "claude -p"              # command that receives the prompt on stdin

[tasks.email]
do = "Read new email and draft replies"
via = "Outlook connector"
limits = "Create drafts only. Never send."   # HARD limits, put in every prompt
when = "weekdays 09:00"

[tasks.tickets]
do = "Read my Jira tickets and start implementing them"
via = "Atlassian connector"
repos = ["~/code/billing-service"]
limits = "Push to feature branches only. Never open PRs."
when = "manual"

[wrapup]
when = "weekdays 17:30"          # or "weekdays 08:30" with covers = "yesterday"
covers = "today"                 # today | yesterday
scan = ["sent email (Outlook)", "Slack messages I sent", "calendar meetings"]   # [] = scan nothing
ask_user = true                  # also prompt me for extra items
notify = "notify-send ayd \"$AYD_MESSAGE\""   # used when asking with no terminal (cron)
```

Task keys: `do` (required), `via`, `limits`, `repos`, `when`, `agent` (per-task override). Unknown keys are errors, so typos are caught.

`when` is `manual` (never scheduled) or one of `every 30m`, `every 2h`, `daily 09:00`, `weekdays 17:30`, `mon,wed,fri 08:00`.

## Commands

| Command | What it does |
|---|---|
| `ayd init [path]` | write a starter config |
| `ayd check` | validate config; show each task's schedule |
| `ayd brief [task\|wrapup]` | print the briefing (rules, task, limits, previous journal, active tracks) |
| `ayd run <task> [--dry-run]` | pipe the briefing to the configured agent. Failures are journaled |
| `ayd wrapup [--dry-run]` | prompt you for extra work (if `ask_user`), then agent scans configured sources and sets next steps |
| `ayd add "text" [--date D]` | record extra work you did yourself |
| `ayd log <task> "text" [-k A\|U\|N\|Q] [--track slug] [--date D]` | append a record (what the agent calls) |
| `ayd track new\|set\|done\|ls\|show` | manage long-running / deadline tracks |
| `ayd schedule [--install\|--uninstall] [--bin PATH]` | print or install crontab entries for tasks whose `when` isn't `manual` |

Manual vs automatic is just `when`: `manual` tasks run only via `ayd run`/the skills; anything else is emitted by `ayd schedule` as cron entries (managed between `# BEGIN ayd` / `# END ayd`; reinstalling replaces them). Cron has a minimal `PATH` and no terminal, so pass `--bin` with an absolute path and make sure your agent CLI is authenticated and permitted to use the needed connectors non-interactively.

## Files written

```
<data_dir>/journal/2026-11-18.ayd   one file per day
<data_dir>/tracks/billing.ayd       one file per long-running / deadline task
```

Both are plain line records, built to be small for an AI to read rather than pretty:

```
#ayd1 2026-11-18
A|09:02|email|drafted 3 replies (ids d1,d2,d3); Bob's needs budget figure
N|09:02|email|send Bob budget draft once Q resolved
Q|09:02|email|which budget version should Bob get: v2 or v3?
U|17:40|wrapup|sent roadmap email to Sam (Outlook)
A|09:40|tickets|#billing ENG-12: branch ayd/eng-12 pushed, tests pass
N|09:40|tickets|#billing ENG-12: add retry test
```
`kind|HH:MM|task|text`, kinds `A` agent did, `U` user did, `N` next step, `Q` open question.

```
#ayd1 track
@title=Migrate billing service
@due=2026-12-01
@status=active
2026-11-18|A|ENG-12 branch ayd/eng-12 pushed
2026-11-18|N|add retry test
```

**What the agent reads before a run:** the most recent journal before today (skipping weekends/gaps), today's journal so far, and every non-`done` track sorted by deadline (last 12 entries each). Nothing else. Older history stays on disk but isn't loaded.

**Next steps and questions:** the prompt requires an `N` line for all unfinished work and a `Q` when the agent is unsure (and to ask you directly in interactive sessions). They are the next run's to-do list.

**Wrapup:** at the time you choose (`covers = "today"` at end of day, or `"yesterday"` the next morning) `ayd wrapup` (1) asks you for extra items if `ask_user`, in a terminal, or else logs a `Q` and runs `notify` so you can `ayd add` later; (2) has the agent scan *only* the sources in `scan`, read-only, logging your work as `U`; (3) sets next steps and updates tracks.

## Limits are instructions, not a sandbox

`limits` are placed in every prompt as hard rules, but enforcement is up to the agent. For real guarantees also restrict the connectors themselves (draft-only mail scope, read-only tokens, branch protection on `main`) and the agent's permission mode.
