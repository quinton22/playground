"""Starter task templates: `ayd template add <name>` appends one to your config."""

from __future__ import annotations

TEMPLATES: dict[str, dict] = {
    "email-triage": dict(
        default="email",
        desc="Triage unread email, draft replies, never send",
        body='''do = "Triage unread email; draft replies where one is needed; list anything urgent"
via = "email connector (Outlook or Gmail)"
limits = "Create drafts only. Never send, delete, archive, or forward anything."
when = "weekdays 09:00"''',
    ),
    "jira-to-branches": dict(
        default="tickets",
        desc="Start work on assigned Jira tickets, push branches, no PRs",
        body='''do = "Read tickets assigned to me and start implementing them"
via = "Atlassian connector (Jira)"
repos = ["~/code/CHANGE-ME"]
limits = "Commit and push to feature branches only. Never open PRs, never touch main, never transition tickets."
when = "weekdays 09:30"''',
    ),
    "pr-review": dict(
        default="reviews",
        desc="Prepare reviews of PRs awaiting you as a pending review",
        body='''do = "Review pull requests that request my review; write findings as a pending review"
via = "GitHub connector"
limits = "Leave a pending/draft review only. Never submit, approve, request changes, or merge."
approval = "ask"
when = "weekdays 11:00"''',
    ),
    "meeting-prep": dict(
        default="meetings",
        desc="Prepare briefs for today's meetings",
        body='''do = "For each meeting today, write a brief: attendees, agenda, related docs and open items from the journal"
via = "calendar connector"
limits = "Read-only. Write briefs into the journal only; send nothing."
when = "weekdays 08:30"''',
    ),
    "slack-catchup": dict(
        default="slack",
        desc="Summarize mentions and draft replies, never post",
        body='''do = "Summarize unread mentions and DMs; draft replies for ones that need me"
via = "Slack connector"
limits = "Read-only. Draft replies in the journal only. Never post, react, or send."
when = "weekdays 12:30"''',
    ),
}


def names() -> list[str]:
    return sorted(TEMPLATES)


def render(name: str, task_name: str | None = None) -> str:
    if name not in TEMPLATES:
        raise ValueError(f"unknown template {name!r} (have: {', '.join(names())})")
    t = TEMPLATES[name]
    return f"[tasks.{task_name or t['default']}]\n{t['body']}\n"
