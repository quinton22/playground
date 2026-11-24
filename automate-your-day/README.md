# automate-your-day (`ayd`)

Config-driven daily work automation for AI agents. You describe, in one short TOML file, **what** to automate, **how**, and **how far** the agent may go. `ayd` runs the agent on a schedule (or on demand), keeps a **compact journal** of everything done, and gives the next run exactly the context it needs: the last journal file plus any active long-running tracks.

It has two parts:

- `ayd` - a zero-dependency Python CLI (briefings, journal, tracks, scheduling, running an agent).
- `plugin/` - a Claude Code plugin with skills: `ayd-setup` (AI-assisted config), `ayd-run`, `ayd-wrapup`, `ayd-inbox` (answer questions / approve actions), `ayd-report` (reviews and promo packets). Any other agent can use the CLI directly: `ayd brief <task>` prints everything it needs to know.

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
requires = ["email", "no-questions:email"]   # only run once email succeeded today with nothing open

[tasks.reviews]
do = "Review PRs awaiting me; write findings as a pending review"
via = "GitHub connector"
limits = "Pending review only. Never submit or merge."
approval = "ask"                 # agent only PROPOSES outward actions; you `ayd approve` them
timeout = "30m"                  # per-task cap (default [ayd] timeout = "1h")
when = "weekdays 11:00"

[wrapup]
when = "weekdays 17:30"          # or "weekdays 08:30" with covers = "yesterday"
covers = "today"                 # today | yesterday
scan = ["sent email (Outlook)", "Slack messages I sent", "calendar meetings"]   # [] = scan nothing
ask_user = true                  # also prompt me for extra items
notify = "notify-send ayd \"$AYD_MESSAGE\""   # used when asking with no terminal (cron)

[digest]                         # optional: short done / next / blockers / deadlines summary
when = "weekdays 08:45"
notify = "notify-send ayd \"$AYD_MESSAGE\""

[rollup]                         # optional: compact weekly (or monthly) summary written by the agent
when = "fri 17:45"
covers = "this-week"             # this-week | last-week | this-month | last-month
```

Task keys: `do` (required), `via`, `limits`, `repos`, `when`, `agent`, `approval`, `requires`, `timeout`. `[ayd]` also takes `timeout` and `nudge_days` (flag track deadlines this close, default 7). Unknown keys are errors, so typos are caught.

`when` is `manual` (never scheduled) or one of `every 30m`, `every 2h`, `daily 09:00`, `weekdays 17:30`, `mon,wed,fri 08:00`. Cron restarts each hour/day, so `every N` must divide evenly (minutes: 1,2,3,4,5,6,10,12,15,20,30; hours: 1,2,3,4,6,8,12); anything else is rejected rather than run unevenly.

## Commands

| Command | What it does |
|---|---|
| `ayd init [path]` / `ayd template ls\|add <name> [--as task]` | write a starter config / append a task template (email-triage, jira-to-branches, pr-review, meeting-prep, slack-catchup) |
| `ayd check` | validate config; show schedule; warn on tasks without limits and near/overdue deadlines |
| `ayd brief [task\|wrapup]` | print the briefing (rules, task, limits, previous journal, questions, approvals, deadlines, tracks) |
| `ayd run <task> [--dry-run] [--force]` | pipe the briefing to the agent. Skips if `requires` unmet or already running; failures/timeouts are journaled |
| `ayd start <task\|wrapup>` / `ayd finish <task> [--failed]` | interactive agents: same `requires` check, overlap guard and run recording as `ayd run` (`start` exits 3 = do not proceed) |
| `ayd wrapup [--dry-run]` | prompt you for extra work (if `ask_user`), then the agent scans configured sources and sets next steps |
| `ayd digest [--notify]` | no-AI summary: done / next / blockers / deadlines / failures (also a standup) |
| `ayd add "text" [--win] [--date D]` | record work you did yourself (`--win` = notable accomplishment) |
| `ayd log <task> "text" [-k A\|U\|N\|Q\|W] [--track slug] [--date D]` | append a record (what the agent calls); `-k Q` registers a question and prints its id |
| `ayd track new\|set\|done\|ls\|show` | manage long-running / deadline tracks |
| `ayd inbox` / `answer qN "text"` / `approve aN...` / `reject aN [why]` / `close id...` | handle questions and proposed actions |
| `ayd stats [--days N]` | runs, failures, skips, avg duration, rough token estimates per task |
| `ayd compact [--keep-days 60] [--keep-entries 30] [--dry-run]` | archive old journal days and track entries; reports still read the archive |
| `ayd rollup run [--period P]` / `add` / `show` | agent-written weekly/monthly summaries (`H` accomplishment, `M` metric, `C` carry-over) |
| `ayd report <review\|promo\|answers\|brag\|ask> ...` | write reviews, promo packets, review answers, accomplishment lists from the record |
| `ayd schedule [--install\|--uninstall] [--bin PATH]` | print or install crontab entries (tasks, wrapup, digest, rollup) |

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
`kind|HH:MM|task|text`, kinds `A` agent did, `U` user did, `N` next step, `Q` open question, `W` notable accomplishment.

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

## Questions and approvals

- **Questions.** When the agent is unsure it runs `ayd log <task> "..." -k Q`, which registers an id (`q3`) and tells it to ask you if the session is interactive. Open questions appear in every briefing (so they are not re-asked) and in `ayd inbox`. `ayd answer q3 "v3"` records your answer; the next run sees it under ANSWERED QUESTIONS, acts, and `ayd close q3`.
- **Approval mode.** With `approval = "ask"` the agent must not send/post/push/comment; it runs `ayd propose <task> "<exact action>"` (`a1`). You `ayd approve a1` or `ayd reject a1 "why"`. The task's next run executes approved actions exactly as written, then closes them; rejected ones are not retried. Approval gating is prompt-level, like `limits`.

## Reliability

- **Overlap guard.** Each task holds an OS-level lock (`flock` on `<data_dir>/locks/<task>.lock`) for the life of its run, so a slow `every 30m` task never runs twice at once, and the lock vanishes if the process dies (no stale-lock cleanup, no startup race). Interactive sessions (`ayd start`/`finish`) take a time-limited marker that scheduled runs respect. Skips are recorded. On platforms without `fcntl` (Windows) locking is unavailable.
- **Timeout.** The agent runs in its own process group; at `timeout` (default `1h`) the whole group is killed (including anything it spawned) before the lock is released, and the run is journaled as a failure.
- **Shared files.** Questions/approvals and tracks are updated under per-file locks with atomic replacement, so tasks running at once do not lose each other's entries. Ids (`q3`, `a5`) are never reused, even after `compact` purges old ones.
- **Dependencies.** `requires = [...]`: `name` (or `ran:name`) = ran successfully today, `no-questions:name`, `no-pending:name`. Unmet = skipped and recorded; `--force` overrides. Order scheduled tasks so prerequisites run first.
- **Stats.** `<data_dir>/runs.ayd` logs each run (`date|time|task|status|secs|rc|~tok in|~tok out|note`). Tokens are chars/4 estimates of the prompt and captured output, not billing numbers.
- **Deadlines.** Tracks with `due` within `nudge_days` (or overdue) show up in briefings, `ayd check`, and the digest.
- **Compaction.** `ayd compact` moves journal days older than `--keep-days` into `journal/archive/YYYY-MM.ayd`, older track entries into `tracks/archive/<slug>.ayd`, and drops old closed ledger items. Briefings stay small; `report` and `rollup` still read archives.

## Rollups, reviews, and promotion packets

Everything the agent logs is evidence. `W` lines (notable accomplishments: shipped, a metric moved, unblocked others) are the strongest; agents are told to log them, and you can add your own: `ayd add "cut checkout p95 by 30%" --win`.

1. **Rollups (optional, recommended).** `ayd rollup run` (or `[rollup]` on a schedule) has the agent condense a week or month into 5-15 lines under `<data_dir>/rollups/2026-W47.ayd`. Each agent-written rollup records how many journal lines it was built from. Report evidence substitutes it for the raw days only while that count still matches; if you logged more afterwards, or the rollup was hand-written (`ayd rollup add`), the raw days are included too, so nothing is hidden. Fresh month rollups beat week rollups, so a full-year report stays small.
2. **Reports.** `ayd report <kind> [--period P] ...` builds a prompt with the evidence and runs your agent; the document is saved to `<data_dir>/reports/`.

```bash
ayd report review  --period last-quarter                       # quarterly self-review
ayd report promo   --period 2026 --target "Senior Engineer" --note "emphasize cross-team impact"
ayd report answers --period 2026 --questions review-questions.txt   # answer end-of-year review questions
ayd report brag    --from 2026-01-01 --to 2026-06-30            # resume-style accomplishment list
ayd report ask     --ask "What did I do on the billing migration?" --period 2026-H2
ayd report review  --period 2026-Q4 --dry-run                   # just show prompt + evidence
```

Periods: `2026`, `2026-Q4`, `2026-H1`, `2026-11`, `2026-W47`, `this-/last-` `week|month|quarter|half|year`. Reports cite dates or `[track:slug]` after each claim, mark missing facts as `[NEEDS INPUT: ...]` instead of guessing, and end with notes on gaps and any substantially AI-assisted work you may want to describe accurately. Review drafts are only as good as what was logged: run wrapup regularly and add wins.

## Limits are instructions, not a sandbox

`limits` are placed in every prompt as hard rules, but enforcement is up to the agent. For real guarantees also restrict the connectors themselves (draft-only mail scope, read-only tokens, branch protection on `main`) and the agent's permission mode.
