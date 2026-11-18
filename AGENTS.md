# Agent Instructions

This repo (`playground`) is a collection of small, one-off projects. These instructions apply to Claude Code, Copilot, Cursor, Codex, and any other AI coding tool.

## Core rule: each directory is a self-contained project

- Every top-level directory is a fully encapsulated project with its own README, dependencies, config, tests, and tooling.
- **Only read, edit, create, or delete files inside the project directory you were asked to work on.** Do not touch other projects or the repo root unless the user explicitly tells you to.
- Do not share code, dependencies, or config between projects, and don't add cross-project imports or references.
- Run commands (install, test, lint, build) from inside the project directory. Keep virtualenvs, `node_modules`, caches, and build output inside it too.
- If a task seems to need changes outside the project (e.g. the root `README.md`, a new project directory), stop and ask first.

## Working in a project

1. Read the project's `README.md` (and its own `AGENTS.md`/`CLAUDE.md` if present) before making changes. Project-level instructions override this file.
2. Follow the project's existing language, structure, and style. Don't introduce new tools or frameworks without a reason.
3. Add or update tests alongside code changes, and run the project's tests before finishing.
4. Don't commit secrets, credentials, or generated artifacts; respect the project's `.gitignore`.

## Adding a new project

Only when asked: create a new top-level directory with a clear kebab-case name containing its own `README.md`, dependency manifest, `.gitignore`, and tests. Leave existing projects and root files alone, except to add a one-line entry to the root `README.md` if the user wants it.

## Current projects

| Directory | Description | Stack |
|---|---|---|
| `estate-sale-monitor/` | Scrapes estate sale sites, analyzes images, and alerts on matches | Python (`pip install -e .`, tests with `pytest`) |
| `civic-message-hub/` | Website to find local lawmaker contacts and draft outreach messages | Python (`pyproject.toml`, tests in `tests/`) |
| `taskweave/` | Collaborative todo app with SMS-based task suggestions | Flutter/Dart (`flutter test`) |
| `thinking-of-u/` | Private mutual "thinking of you" matching app | Flutter/Dart + Firebase (`flutter test`) |

## Git

- Keep commits scoped to a single project where possible; mention the project in the commit message (e.g. `estate-sale-monitor: fix scraper pagination`).
- Use the branch you were given; don't push elsewhere without permission.
