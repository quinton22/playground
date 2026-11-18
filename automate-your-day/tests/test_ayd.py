from datetime import date, datetime

import pytest

from ayd import brief, journal, schedule, tracks
from ayd.cli import main
from ayd.config import ConfigError, find_config, load

NOW = datetime(2026, 11, 18, 17, 30)


def write_cfg(tmp_path, body=None, agent="cat"):
    body = body or f"""
[ayd]
data_dir = "data"
agent = "{agent}"

[tasks.email]
do = "Triage email"
via = "Outlook connector"
limits = "Drafts only. Never send."
when = "weekdays 09:00"

[tasks.tickets]
do = "Work Jira tickets"
repos = ["~/code/x"]
limits = "Branches only, no PRs."

[wrapup]
when = "weekdays 17:30"
scan = ["sent email", "slack messages"]
ask_user = true
"""
    p = tmp_path / "ayd.toml"
    p.write_text(body)
    return p


@pytest.fixture
def cfg(tmp_path):
    return load(write_cfg(tmp_path))


# --- schedule ---
@pytest.mark.parametrize("when,cron", [
    ("manual", None),
    ("every 30m", "*/30 * * * *"),
    ("every 2h", "0 */2 * * *"),
    ("daily 09:05", "5 9 * * *"),
    ("weekdays 17:30", "30 17 * * 1-5"),
    ("mon,wed,fri 08:00", "0 8 * * 1,3,5"),
])
def test_parse_when(when, cron):
    assert schedule.parse_when(when) == cron


@pytest.mark.parametrize("bad", ["every 90m", "daily 25:00", "funday 09:00", "sometimes"])
def test_parse_when_bad(bad):
    with pytest.raises(ValueError):
        schedule.parse_when(bad)


def test_crontab_merge_replaces_block():
    block = schedule.crontab_block([("0 9 * * *", "run a")], "/c/ayd.toml")
    first = schedule.merge_crontab("MAILTO=me\n", block)
    second = schedule.merge_crontab(first, block)
    assert first == second
    assert first.startswith("MAILTO=me\n") and first.count("run a") == 1
    assert schedule.strip_block(second) == "MAILTO=me\n"


# --- config ---
def test_load_config(cfg):
    assert cfg.tasks["email"].cron == "0 9 * * 1-5"
    assert cfg.tasks["tickets"].cron is None
    assert cfg.wrapup.ask_user and cfg.data_dir.name == "data"


@pytest.mark.parametrize("body,msg", [
    ('[tasks.a]\ndo="x"\nwhne="y"', "unknown key"),
    ('[tasks.a]\nvia="x"', "'do' is required"),
    ('[tasks.a]\ndo="x"\nwhen="whenever"', "cannot parse"),
    ('[tasks.wrapup]\ndo="x"', "reserved"),
    ('[wrapup]\ncovers="tomorrow"', "covers"),
    ("[tasks", "invalid TOML"),
])
def test_config_errors(tmp_path, body, msg):
    with pytest.raises(ConfigError, match=msg):
        load(write_cfg(tmp_path, body))


def test_find_config_explicit_missing(tmp_path):
    with pytest.raises(ConfigError):
        find_config(str(tmp_path / "nope.toml"))


# --- journal ---
def test_journal_append_and_previous(cfg):
    journal.append(cfg, "A", "email", "drafted 3 | 1 needs input", datetime(2026, 11, 13, 9, 0))
    journal.append(cfg, "N", "email", "await Bob\nre budget", datetime(2026, 11, 13, 9, 1))
    text = journal.read_day(cfg, date(2026, 11, 13))
    assert text.splitlines() == [
        "#ayd1 2026-11-13",
        "A|09:00|email|drafted 3 / 1 needs input",
        "N|09:01|email|await Bob re budget",
    ]
    prev = journal.previous_day(cfg, date(2026, 11, 16))  # Monday skips the weekend
    assert prev and prev[0] == date(2026, 11, 13)
    assert journal.previous_day(cfg, date(2026, 11, 13)) is None
    with pytest.raises(ValueError):
        journal.append(cfg, "X", "t", "t", NOW)


# --- tracks ---
def test_tracks_lifecycle(cfg):
    tracks.create(cfg, "billing", "Migrate billing", "2026-12-01")
    tracks.create(cfg, "later", "No deadline")
    tracks.append(cfg, "billing", "N", "write tests", NOW)
    tracks.set_meta(cfg, "later", "status", "paused")
    assert [t.slug for t in tracks.active(cfg)] == ["billing", "later"]
    tracks.set_meta(cfg, "later", "status", "done")
    assert [t.slug for t in tracks.active(cfg)] == ["billing"]
    out = tracks.render(tracks.load(cfg, "billing"))
    assert "due=2026-12-01" in out and "2026-11-18|N|write tests" in out
    with pytest.raises(tracks.TrackError):
        tracks.create(cfg, "billing", "dup")
    with pytest.raises(tracks.TrackError):
        tracks.set_meta(cfg, "billing", "due", "tomorrow")
    with pytest.raises(tracks.TrackError):
        tracks.load(cfg, "../etc")


def test_render_truncates(cfg):
    t = tracks.create(cfg, "long", "Long")
    for i in range(20):
        tracks.append(cfg, "long", "A", f"step {i}", NOW)
    out = tracks.render(tracks.load(cfg, "long"), tail=5)
    assert "(+15 earlier" in out and "step 19" in out and "step 0|" not in out


# --- brief ---
def test_brief_contains_only_pertinent_context(cfg):
    journal.append(cfg, "N", "email", "reply to Bob", datetime(2026, 11, 16, 16, 0))
    journal.append(cfg, "N", "email", "OLD", datetime(2026, 11, 2, 16, 0))
    tracks.create(cfg, "billing", "Billing", "2026-12-01")
    tracks.create(cfg, "done-one", "Finished")
    tracks.set_meta(cfg, "done-one", "status", "done")
    text = brief.build(cfg, "email", NOW)
    assert "limits (HARD): Drafts only. Never send." in text
    assert "reply to Bob" in text and "OLD" not in text
    assert "== billing" in text and "done-one" not in text


def test_wrapup_brief_covers_yesterday(tmp_path):
    body = '[wrapup]\ncovers="yesterday"\nscan=["calendar"]\n'
    cfg = load(write_cfg(tmp_path, body))
    text = brief.build(cfg, "wrapup", NOW)
    assert "--date 2026-11-17" in text and "- calendar" in text


# --- cli ---
def test_cli_init_check_log_track(tmp_path, capsys, monkeypatch):
    monkeypatch.chdir(tmp_path)
    assert main(["init"]) == 0
    assert main(["init"]) == 1  # no overwrite
    assert main(["check"]) == 0
    assert main(["log", "email", "drafted 2", "--track", "nope"]) == 1
    assert main(["track", "new", "t1", "--title", "T", "--due", "2026-12-01"]) == 0
    assert main(["log", "email", "drafted 2", "-k", "A", "--track", "t1"]) == 0
    assert main(["add", "met with Sam"]) == 0
    day = next((tmp_path / "ayd-data" / "journal").glob("*.ayd")).read_text()
    assert "|email|#t1 drafted 2" in day and "U|" in day and "|user|met with Sam" in day
    capsys.readouterr()
    assert main(["track", "ls"]) == 0
    assert "t1" in capsys.readouterr().out


def test_cli_run_pipes_prompt_to_agent(tmp_path, capfd):
    p = write_cfg(tmp_path, agent="cat")
    assert main(["-c", str(p), "run", "email"]) == 0
    out = capfd.readouterr().out
    assert "TASK email" in out


def test_cli_run_failure_is_logged(tmp_path):
    p = write_cfg(tmp_path, agent="false")
    assert main(["-c", str(p), "run", "email"]) == 1
    files = list((tmp_path / "data" / "journal").glob("*.ayd"))
    assert files and "FAILED agent exit 1" in files[0].read_text()


def test_cli_wrapup_noninteractive_leaves_question(tmp_path, monkeypatch):
    p = write_cfg(tmp_path, agent="true")
    assert main(["-c", str(p), "wrapup"]) == 0
    text = next((tmp_path / "data" / "journal").glob("*.ayd")).read_text()
    assert "Q|" in text and "ayd add" in text


def test_cli_unknown_task(tmp_path):
    p = write_cfg(tmp_path)
    assert main(["-c", str(p), "run", "nope"]) == 1
    assert main(["-c", str(p), "schedule"]) == 0


def test_check_warns_on_missing_limits(tmp_path, capsys):
    p = write_cfg(tmp_path, '[tasks.a]\ndo="x"\n[tasks.b]\ndo="y"\nlimits="read-only"\n')
    assert main(["-c", str(p), "check"]) == 0
    err = capsys.readouterr().err
    assert "task 'a' has no limits" in err and "task 'b'" not in err
