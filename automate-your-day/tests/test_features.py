import os
import time
from datetime import date, datetime, timedelta

import pytest

from ayd import brief, compact, digest, history, journal, ledger, periods, report, runner, templates, tracks
from ayd.cli import main
from ayd.config import ConfigError, load

NOW = datetime(2026, 11, 18, 17, 30)  # Wednesday


def write_cfg(tmp_path, extra="", agent="cat"):
    p = tmp_path / "ayd.toml"
    p.write_text(f'''
[ayd]
data_dir = "data"
agent = "{agent}"
timeout = "5m"

[tasks.email]
do = "Triage email"
limits = "Drafts only."

[tasks.tickets]
do = "Work tickets"
limits = "Branches only."
requires = ["email", "no-questions:email"]

[tasks.send]
do = "Send replies"
limits = "Only approved."
approval = "ask"
{extra}
''')
    return p


@pytest.fixture
def cfg(tmp_path):
    return load(write_cfg(tmp_path))


# ---- config
@pytest.mark.parametrize("body,msg", [
    ('[tasks.a]\ndo="x"\napproval="maybe"', "approval"),
    ('[tasks.a]\ndo="x"\nrequires=["zzz"]', "unknown task"),
    ('[tasks.a]\ndo="x"\nrequires=["a"]', "itself"),
    ('[tasks.a]\ndo="x"\nrequires=["bad:thing:x"]', "bad requirement"),
    ('[tasks.a]\ndo="x"\ntimeout="soon"', "duration"),
    ('[ayd]\nnudge_days=-1', "nudge_days"),
    ('[rollup]\ncovers="forever"', "covers"),
    ('[tasks.digest]\ndo="x"', "reserved"),
])
def test_new_config_errors(tmp_path, body, msg):
    p = tmp_path / "c.toml"
    p.write_text(body)
    with pytest.raises(ConfigError, match=msg):
        load(p)


def test_digest_rollup_sections(tmp_path):
    p = write_cfg(tmp_path, '[digest]\nwhen="weekdays 08:45"\n[rollup]\nwhen="fri 17:45"\ncovers="last-week"')
    c = load(p)
    assert c.digest.cron == "45 8 * * 1-5" and c.rollup.cron == "45 17 * * 5" and c.timeout == 300
    main(["-c", str(p), "schedule"])


# ---- periods
@pytest.mark.parametrize("spec,start,end", [
    ("2026", date(2026, 1, 1), date(2026, 12, 31)),
    ("2026-Q4", date(2026, 10, 1), date(2026, 12, 31)),
    ("2026-H1", date(2026, 1, 1), date(2026, 6, 30)),
    ("2026-02", date(2026, 2, 1), date(2026, 2, 28)),
    ("2026-W47", date(2026, 11, 16), date(2026, 11, 22)),
    ("this-week", date(2026, 11, 16), date(2026, 11, 22)),
    ("last-week", date(2026, 11, 9), date(2026, 11, 15)),
    ("last-quarter", date(2026, 7, 1), date(2026, 9, 30)),
    ("last-year", date(2025, 1, 1), date(2025, 12, 31)),
    ("last-month", date(2026, 10, 1), date(2026, 10, 31)),
])
def test_periods(spec, start, end):
    p = periods.parse(spec, NOW.date())
    assert (p.start, p.end) == (start, end)


def test_periods_bad():
    for bad in ("2026-Q5", "2026-13", "soon", "2026-W99"):
        with pytest.raises(ValueError):
            periods.parse(bad, NOW.date())
    assert periods.parse("last-quarter", date(2026, 1, 5)).label == "2025-Q4"


# ---- ledger: questions + approvals
def test_question_lifecycle_via_cli(tmp_path, capsys):
    p = write_cfg(tmp_path)
    c = ["-c", str(p)]
    assert main(c + ["log", "email", "v2 or v3?", "-k", "Q"]) == 0
    assert capsys.readouterr().out.strip() == "q1"
    assert "OPEN QUESTIONS" in brief.build(load(p), "email", datetime.now())
    assert main(c + ["inbox"]) == 0 and "q1" in capsys.readouterr().out
    assert main(c + ["answer", "q1", "v3"]) == 0
    text = brief.build(load(p), "email", datetime.now())
    assert "ANSWERED QUESTIONS" in text and "=> v3" in text and "OPEN QUESTIONS" not in text
    assert main(c + ["close", "q1"]) == 0
    assert "QUESTIONS" not in brief.build(load(p), "email", datetime.now())
    assert main(c + ["answer", "q9", "x"]) == 1
    assert main(c + ["approve", "q1"]) == 1  # wrong kind


def test_approval_flow(tmp_path, capsys):
    p = write_cfg(tmp_path)
    c = ["-c", str(p)]
    cfg = load(p)
    assert "APPROVAL MODE: ask" in brief.build(cfg, "send", NOW)
    assert "APPROVAL MODE" not in brief.build(cfg, "email", NOW)
    assert main(c + ["propose", "send", "reply to Bob (draft d1)"]) == 0
    assert "PENDING ACTIONS" in brief.build(load(p), "send", NOW)
    assert main(c + ["approve", "a1"]) == 0
    t = brief.build(load(p), "send", NOW)
    assert "APPROVED ACTIONS" in t and "reply to Bob" in t
    assert "APPROVED ACTIONS" not in brief.build(load(p), "email", NOW)  # scoped to task
    assert main(c + ["propose", "send", "post to #eng"]) == 0
    assert main(c + ["reject", "a2", "not now"]) == 0
    assert "not now" in brief.build(load(p), "send", NOW)
    main(c + ["close", "a1", "a2"])
    assert "ACTIONS" not in brief.build(load(p), "send", NOW)
    assert main(c + ["propose", "nope", "x"]) == 1


# ---- requirements, locks, timeouts, stats
def test_requires_gate_run(tmp_path, capsys):
    p = write_cfg(tmp_path, agent="true")
    c = ["-c", str(p)]
    assert main(c + ["run", "tickets"]) == 0  # skipped: email has not run
    runs = runner.read_runs(load(p))
    assert runs[-1].status == "skipped" and "email" in runs[-1].note
    assert main(c + ["run", "email"]) == 0
    main(c + ["log", "email", "which?", "-k", "Q"])
    assert main(c + ["run", "tickets"]) == 0
    assert "open questions" in runner.read_runs(load(p))[-1].note
    main(c + ["close", "q1"])
    assert main(c + ["run", "tickets"]) == 0
    assert runner.read_runs(load(p))[-1].status == "ok"
    assert main(c + ["run", "tickets", "--dry-run"]) == 0


def test_force_ignores_requires(tmp_path):
    p = write_cfg(tmp_path, agent="true")
    assert main(["-c", str(p), "run", "tickets", "--force"]) == 0
    assert runner.read_runs(load(p))[-1].status == "ok"


def test_overlap_lock_skips(tmp_path):
    p = write_cfg(tmp_path, agent="true")
    cfg = load(p)
    lock = runner.acquire(cfg, "email")
    assert lock and runner.acquire(cfg, "email") is None
    assert main(["-c", str(p), "run", "email"]) == 0
    assert runner.read_runs(cfg)[-1].status == "skipped"
    runner.release(lock)
    again = runner.acquire(cfg, "email")  # lock file persists; ownership is the OS lock, so no stale reclaim races
    assert again
    runner.release(again)


def test_lock_released_when_holder_dies(tmp_path):
    import subprocess, sys
    cfg = load(write_cfg(tmp_path))
    code = ("import sys,time;from ayd import runner;from ayd.config import load;from pathlib import Path;"
            f"c=load(Path({str(tmp_path / 'ayd.toml')!r}));f=runner.acquire(c,'email');print('held',flush=True);time.sleep(60)")
    proc = subprocess.Popen([sys.executable, "-c", code], stdout=subprocess.PIPE, text=True)
    try:
        assert proc.stdout.readline().strip() == "held"
        assert runner.acquire(cfg, "email") is None
    finally:
        proc.kill()
        proc.wait()
    got = runner.acquire(cfg, "email")
    assert got
    runner.release(got)


def test_interactive_session_lifecycle(tmp_path, capsys):
    p = write_cfg(tmp_path, agent="true")
    c = ["-c", str(p)]
    assert main(c + ["start", "tickets"]) == 3          # requires email first
    assert "do not start tickets" in capsys.readouterr().err
    assert main(c + ["start", "email"]) == 0
    assert "TASK email" in capsys.readouterr().out
    assert main(c + ["start", "email"]) == 3             # already in progress
    assert main(c + ["run", "email"]) == 0               # scheduled run yields to the session
    assert runner.read_runs(load(p))[-1].status == "skipped"
    assert main(c + ["finish", "email"]) == 0
    assert runner.read_runs(load(p))[-1].status == "ok"  # now satisfies requires
    assert main(c + ["start", "tickets"]) == 0
    assert main(c + ["finish", "tickets", "--failed", "--note", "boom"]) == 0
    assert runner.read_runs(load(p))[-1].status == "failed"
    assert "FAILED (interactive)" in journal.read_day(load(p), datetime.now().date())
    assert main(c + ["start", "nope"]) == 1
    assert main(c + ["start", "wrapup"]) == 1            # no [wrapup] in this config


def test_timeout_kills_and_logs(tmp_path):
    cfg = load(write_cfg(tmp_path, agent="sleep 30"))
    res = runner.run_agent(cfg, "email", "sleep 30", "x", NOW, timeout=1)
    assert res.status == "timeout" and res.exit_code == 124
    assert runner.read_runs(cfg)[-1].status == "timeout"
    assert "FAILED (timeout" in journal.read_day(cfg, NOW.date())
    got = runner.acquire(cfg, "email")
    assert got
    runner.release(got)


def test_timeout_kills_spawned_children(tmp_path):
    import os, subprocess
    marker = tmp_path / "child.pid"
    script = tmp_path / "agent.sh"
    script.write_text(f"#!/bin/sh\nsleep 300 &\necho $! > {marker}\nwait\n")
    script.chmod(0o755)
    cfg = load(write_cfg(tmp_path, agent=str(script)))
    res = runner.run_agent(cfg, "email", str(script), "x", NOW, timeout=1)
    assert res.status == "timeout"
    pid = int(marker.read_text())
    for _ in range(50):
        try:
            os.kill(pid, 0)
            time.sleep(0.1)
        except ProcessLookupError:
            break
    else:
        os.kill(pid, 9)
        pytest.fail("grandchild survived the timeout")


def test_stats(tmp_path, capsys):
    p = write_cfg(tmp_path, agent="cat")
    main(["-c", str(p), "run", "email"])
    capsys.readouterr()
    assert main(["-c", str(p), "stats"]) == 0
    out = capsys.readouterr().out
    assert "email" in out and "~tok in" in out
    rows = runner.stats(load(p), date(2000, 1, 1))
    assert rows[0]["runs"] == 1 and rows[0]["tin"] > 0 and rows[0]["tout"] > 0


# ---- digest + deadlines
def test_digest_and_deadlines(cfg):
    journal.append(cfg, "A", "email", "drafted 3", datetime(2026, 11, 17, 9, 0))
    journal.append(cfg, "W", "tickets", "ENG-12 shipped, p95 -30%", datetime(2026, 11, 17, 15, 0))
    journal.append(cfg, "N", "email", "send Bob budget", datetime(2026, 11, 17, 16, 0))
    ledger.questions(cfg).add("email", "v2 or v3?", NOW)
    ledger.actions(cfg).add("send", "reply to Bob", NOW)
    tracks.create(cfg, "billing", "Billing", "2026-11-20")
    tracks.create(cfg, "late", "Late", "2026-11-15")
    tracks.create(cfg, "far", "Far", "2027-01-01")
    runner.record(cfg, NOW, "email", "timeout")
    text = digest.build(cfg, NOW)
    for needle in ("Done 2026-11-17:", "* tickets: ENG-12 shipped", "Next:", "q1", "approve?",
                   "billing: due in 2d", "late: OVERDUE by 3d", "Failures (24h):"):
        assert needle in text
    assert "far:" not in text
    assert "DEADLINES" in brief.build(cfg, "email", NOW)


def test_digest_empty_and_notify(tmp_path, capsys):
    p = write_cfg(tmp_path, f'[digest]\nnotify="echo \\"$AYD_MESSAGE\\" > {tmp_path}/msg.txt"')
    assert main(["-c", str(p), "digest", "--notify"]) == 0
    assert "Nothing to report" in (tmp_path / "msg.txt").read_text()
    sub = tmp_path / "x"
    sub.mkdir()
    q = write_cfg(sub)
    assert main(["-c", str(q), "digest", "--notify"]) == 1  # no [digest] notify


# ---- compaction + history
def test_compact_archives_but_history_still_reads(cfg):
    old = datetime(2026, 5, 4, 9, 0)
    journal.append(cfg, "W", "t", "old win", old)
    journal.append(cfg, "A", "t", "recent", datetime(2026, 11, 17, 9, 0))
    tracks.create(cfg, "long", "Long")
    for i in range(40):
        tracks.append(cfg, "long", "A", f"step {i}", old)
    dry = compact.compact(cfg, NOW.date(), dry_run=True)
    assert dry["days"] == 1 and dry["track_entries"] == 10
    assert journal.day_file(cfg, old.date()).exists()
    res = compact.compact(cfg, NOW.date(), keep_days=60, keep_entries=30)
    assert res["days"] == 1 and res["track_entries"] == 10
    assert not journal.day_file(cfg, old.date()).exists()
    assert (cfg.journal_dir / "archive" / "2026-05.ayd").exists()
    assert history.days(cfg, date(2026, 5, 1), date(2026, 5, 31))[date(2026, 5, 4)] == ["W|09:00|t|old win"]
    assert len(tracks.load(cfg, "long").entries) == 30
    assert len(history.track_entries(cfg, "long")) == 40
    assert compact.compact(cfg, NOW.date())["days"] == 0  # idempotent


def test_closed_ledger_items_purged(cfg):
    q = ledger.questions(cfg)
    a = q.add("t", "old", datetime(2026, 1, 1, 9, 0))
    q.set_status(a, "X")
    q.add("t", "open old", datetime(2026, 1, 1, 9, 0))
    assert compact.compact(cfg, NOW.date())["ledger_items"] == 1
    assert [i.text for i in q.all()] == ["open old"]


# ---- rollups and reports
def _fresh_rollup(cfg, label, lines, today=NOW.date()):
    history.rollup_write(cfg, label, lines, src=history.count_lines(cfg, periods.parse(label, today)))


def test_pack_prefers_fresh_rollups(cfg):
    for d in range(16, 23):  # week 47
        journal.append(cfg, "A", "t", f"raw {d}", datetime(2026, 11, d, 9, 0))
    journal.append(cfg, "A", "t", "raw 24", datetime(2026, 11, 24, 9, 0))
    _fresh_rollup(cfg, "2026-W47", ["H|shipped billing v2 [2026-11-18]"])
    pk, info = history.pack(cfg, periods.parse("2026-11", NOW.date()))
    assert "shipped billing v2" in pk and "raw 24" in pk and "raw 17" not in pk
    assert info["rollups"] == 1 and info["days"] == 1
    pk2, _ = history.pack(cfg, periods.parse("2026-W47", NOW.date()), exclude="2026-W47")
    assert "raw 17" in pk2 and "shipped billing" not in pk2
    with pytest.raises(ValueError):
        history.rollup_add(cfg, "2026-W47", "Z", "x")


def test_stale_or_handwritten_rollup_does_not_hide_raw_entries(cfg):
    journal.append(cfg, "A", "t", "early", datetime(2026, 11, 16, 9, 0))
    _fresh_rollup(cfg, "2026-W47", ["H|summary"])
    journal.append(cfg, "W", "t", "late friday win", datetime(2026, 11, 20, 18, 0))  # logged after the rollup
    pk, info = history.pack(cfg, periods.parse("2026-W47", NOW.date()))
    assert "summary" in pk and "late friday win" in pk and "early" in pk and info["rollups"] == 0
    history.rollup_add(cfg, "2026-W46", "H", "hand written only")  # no src => never replaces raw days
    journal.append(cfg, "A", "t", "w46 raw", datetime(2026, 11, 10, 9, 0))
    pk, _ = history.pack(cfg, periods.parse("2026-11", NOW.date()))
    assert "hand written only" in pk and "w46 raw" in pk
    assert history.rollup_src(cfg, "2026-W46") is None
    history.rollup_add(cfg, "2026-W47", "C", "extra")  # appending keeps the original fingerprint
    assert history.rollup_src(cfg, "2026-W47") == 1


def test_month_rollup_beats_week_rollups(cfg):
    journal.append(cfg, "A", "t", "oct raw", datetime(2026, 10, 14, 9, 0))
    _fresh_rollup(cfg, "2026-10", ["H|october summary"])
    _fresh_rollup(cfg, "2026-W42", ["H|week 42 detail"])  # inside October
    pk, info = history.pack(cfg, periods.parse("2026-Q4", NOW.date()))
    assert "october summary" in pk and "week 42 detail" not in pk and "oct raw" not in pk


def test_parse_rollup_output():
    out = "Here you go:\nH|Shipped billing v2 | -30% p95 [2026-11-18]\n- M|42 PRs reviewed\nC|migration half done\nrandom\nZ|no\n"
    assert report.parse_rollup_output(out) == [
        "H|Shipped billing v2 / -30% p95 [2026-11-18]", "M|42 PRs reviewed", "C|migration half done"]


def test_rollup_run_saves_agent_lines(tmp_path):
    out = tmp_path / "out.txt"
    out.write_text("H|did a thing [2026-11-17]\nM|3 PRs\n")
    p = write_cfg(tmp_path, agent=f"cat {out}")
    assert main(["-c", str(p), "rollup", "run", "--period", "2026-W47"]) == 0
    assert history.rollup_read(load(p), "2026-W47") == ["H|did a thing [2026-11-17]", "M|3 PRs"]
    assert history.rollup_src(load(p), "2026-W47") == 0
    assert main(["-c", str(p), "rollup", "add", "2026-W40", "hand written", "-k", "C"]) == 0
    assert main(["-c", str(p), "rollup", "show", "2026-W40"]) == 0
    assert main(["-c", str(p), "rollup", "add", "this-week", "alias"]) == 0   # canonicalized to a real label
    assert history.rollup_read(load(p), periods.parse("this-week", datetime.now().date()).label) == ["H|alias"]
    assert main(["-c", str(p), "rollup", "add", "../../evil", "x"]) == 1
    assert not (tmp_path / "evil.ayd").exists()


def test_rollup_run_without_lines_fails(tmp_path):
    p = write_cfg(tmp_path, agent="echo nothing useful")
    assert main(["-c", str(p), "rollup", "run", "--period", "2026-W47"]) == 1
    assert not history.rollup_path(load(p), "2026-W47").exists()


def test_report_prompts(cfg, tmp_path):
    journal.append(cfg, "W", "tickets", "cut build time 40%", datetime(2026, 3, 3, 9, 0))
    tracks.create(cfg, "billing", "Billing")
    tracks.append(cfg, "billing", "A", "launched", datetime(2026, 3, 9, 9, 0))
    per = periods.parse("2026-Q1", NOW.date())
    text, info = report.build_report(cfg, "review", per)
    assert "self-review" in text and "cut build time 40%" in text and "[NEEDS INPUT" in text
    assert "== billing" in text and info["days"] == 1 and info["tracks"] == 1
    promo, _ = report.build_report(cfg, "promo", per, target="Senior Engineer", note="focus on leadership")
    assert "promotion packet for Senior Engineer" in promo and "focus on leadership" in promo
    ans, _ = report.build_report(cfg, "answers", per, questions="1. Biggest win?\n2. Biggest miss?")
    assert "1. Biggest win?" in ans
    with pytest.raises(ValueError):
        report.build_report(cfg, "answers", per)
    with pytest.raises(ValueError):
        report.build_report(cfg, "ask", per)
    assert "REQUEST\nsummarize my leadership" in report.build_report(cfg, "ask", per, ask="summarize my leadership")[0]


def test_report_cli_saves_output(tmp_path):
    p = write_cfg(tmp_path, agent="echo # My review")
    cfg = load(p)
    journal.append(cfg, "W", "t", "big win", datetime(2026, 3, 3, 9, 0))
    q = tmp_path / "qs.txt"
    q.write_text("What went well?")
    assert main(["-c", str(p), "report", "review", "--period", "2026-Q1"]) == 0
    saved = cfg.reports_dir / "review-2026-Q1.md"
    assert "# My review" in saved.read_text()
    assert main(["-c", str(p), "report", "review", "--period", "2026-Q1"]) == 0  # no overwrite
    assert len(list(cfg.reports_dir.glob("review-2026-Q1*.md"))) == 2
    out = tmp_path / "answers.md"
    assert main(["-c", str(p), "report", "answers", "--questions", str(q), "--period", "2026", "--out", str(out)]) == 0
    assert out.exists()
    assert main(["-c", str(p), "report", "answers", "--period", "2026"]) == 1  # missing questions
    assert main(["-c", str(p), "report", "brag", "--from", "2026-01-01"]) == 1  # --from without --to
    assert main(["-c", str(p), "report", "brag", "--from", "2026-01-01", "--to", "2026-06-30", "--dry-run"]) == 0


def test_add_win(tmp_path):
    p = write_cfg(tmp_path)
    assert main(["-c", str(p), "add", "led incident response", "--win"]) == 0
    assert "W|" in journal.read_day(load(p), datetime.now().date())


# ---- templates
def test_templates(tmp_path, capsys):
    p = write_cfg(tmp_path)
    assert main(["-c", str(p), "template", "ls"]) == 0
    assert "email-triage" in capsys.readouterr().out
    assert main(["-c", str(p), "template", "add", "pr-review"]) == 0
    assert load(p).tasks["reviews"].approval == "ask"
    assert main(["-c", str(p), "template", "add", "pr-review"]) == 1  # duplicate table -> invalid TOML, rolled back
    assert "reviews" in load(p).tasks
    assert main(["-c", str(p), "template", "add", "meeting-prep", "--as", "prep"]) == 0
    assert "prep" in load(p).tasks
    assert main(["-c", str(p), "template", "add", "nope"]) == 1
    for n in templates.names():
        assert templates.render(n).startswith("[tasks.")


# ---- review-fix regressions
def test_ledger_ids_never_reused_after_purge(cfg):
    led = ledger.actions(cfg)
    a1 = led.add("send", "first", datetime(2026, 1, 1, 9, 0))
    led.set_status(a1, "X")
    assert led.purge_closed(date(2026, 6, 1)) == 1 and led.all() == []
    assert led.add("send", "second", NOW) == "a2"


def test_ledger_concurrent_adds_get_unique_ids(tmp_path):
    import multiprocessing as mp
    cfg_path = write_cfg(tmp_path)
    with mp.get_context("fork").Pool(6) as pool:
        ids = pool.map(_add_question, [str(cfg_path)] * 24)
    assert len(set(ids)) == 24
    assert len(ledger.questions(load(cfg_path)).all()) == 24


def _add_question(cfg_path):
    from pathlib import Path
    return ledger.questions(load(Path(cfg_path))).add("t", "q", NOW)


def test_track_updates_do_not_lose_concurrent_appends(tmp_path):
    import multiprocessing as mp
    p = write_cfg(tmp_path)
    tracks.create(load(p), "shared", "Shared")
    with mp.get_context("fork").Pool(6) as pool:
        pool.map(_track_work, [(str(p), i) for i in range(30)])
    t = tracks.load(load(p), "shared")
    assert len(t.entries) == 15  # none of the 15 appends was overwritten by a concurrent metadata update
    assert t.meta["status"] in ("paused", "active")


def _track_work(arg):
    from pathlib import Path
    path, i = arg
    cfg = load(Path(path))
    if i % 2:
        tracks.set_meta(cfg, "shared", "status", "paused" if i % 4 == 1 else "active")
    else:
        tracks.append(cfg, "shared", "A", f"e{i}", NOW)


def test_wrapup_and_overview_do_not_execute_task_approvals(cfg):
    ledger.actions(cfg).add("send", "reply to Bob", NOW)
    ledger.actions(cfg).set_status("a1", "A")
    for task in ("wrapup", None):
        text = brief.build(load(cfg.path) if False else _with_wrapup(cfg), task, NOW)
        assert "APPROVED ACTIONS (execute" not in text and "reply to Bob" not in text
        assert "1 approved" in text
    assert "APPROVED ACTIONS (execute" in brief.build(cfg, "send", NOW)


def _with_wrapup(cfg):
    from ayd.config import Wrapup
    cfg.wrapup = Wrapup(scan=["x"])
    return cfg


def test_overview_is_selection_only(cfg):
    text = brief.build(cfg, None, NOW)
    assert "overview for choosing only" in text and "ayd start <task>" in text
    assert "Pick up from the context" not in text


def test_track_log_uses_requested_date(tmp_path):
    p = write_cfg(tmp_path)
    c = ["-c", str(p)]
    main(c + ["track", "new", "t1"])
    assert main(c + ["log", "email", "did x", "--track", "t1", "--date", "2026-11-17"]) == 0
    assert tracks.load(load(p), "t1").entries == ["2026-11-17|A|did x"]
    assert "2026-11-17.ayd" in [f.name for f in (tmp_path / "data" / "journal").iterdir()]


def test_wrapup_briefing_includes_fallback_question(tmp_path):
    p = write_cfg(tmp_path, '[wrapup]\nask_user = true\nscan = ["x"]', agent="cat")
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        assert main(["-c", str(p), "wrapup"]) == 0
    assert "user not asked (no terminal)" in buf.getvalue()


def test_report_default_filename_never_overwrites(tmp_path):
    p = write_cfg(tmp_path, agent="echo # doc")
    for _ in range(3):
        assert main(["-c", str(p), "report", "brag", "--period", "2026"]) == 0
    names = sorted(f.name for f in (tmp_path / "data" / "reports").iterdir())
    assert names == ["brag-2026-2.md", "brag-2026-3.md", "brag-2026.md"]


def test_digest_without_notify_schedules_without_flag(tmp_path, capsys):
    p = write_cfg(tmp_path, '[digest]\nwhen = "weekdays 08:45"')
    assert main(["-c", str(p), "schedule"]) == 0
    out = capsys.readouterr().out
    assert out.strip().splitlines()[-2].endswith(" digest") and "--notify" not in out
    q = write_cfg(tmp_path / "n" if (tmp_path / "n").mkdir() is None else tmp_path,
                  '[digest]\nwhen = "weekdays 08:45"\nnotify = "true"')
    main(["-c", str(q), "schedule"])
    assert "digest --notify" in capsys.readouterr().out


@pytest.mark.parametrize("body", ['tasks = []', 'ayd = 1', 'wrapup = "x"', 'digest = []', 'rollup = 3'])
def test_non_table_sections_are_config_errors(tmp_path, body, capsys):
    p = tmp_path / "c.toml"
    p.write_text(body)
    with pytest.raises(ConfigError, match="must be a table"):
        load(p)
    assert main(["-c", str(p), "check"]) == 1
    assert "Traceback" not in capsys.readouterr().err


@pytest.mark.parametrize("when,ok", [("every 30m", True), ("every 15m", True), ("every 40m", False),
                                     ("every 7m", False), ("every 2h", True), ("every 5h", False),
                                     ("every 8h", True), ("every 24h", False)])
def test_even_intervals_only(when, ok):
    from ayd import schedule
    if ok:
        assert schedule.parse_when(when)
    else:
        with pytest.raises(ValueError, match="divide evenly"):
            schedule.parse_when(when)
