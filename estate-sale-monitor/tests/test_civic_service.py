"""Tests for civic website service helpers."""

from pathlib import Path

from estate_sale_monitor.civic_service import (
    LawmakerContact,
    add_subject,
    generate_issue_message,
    get_local_lawmakers,
    list_subjects,
)


def test_get_local_lawmakers_uses_fallback_for_unknown_zip(monkeypatch):
    monkeypatch.delenv("GOOGLE_CIVIC_API_KEY", raising=False)
    contacts = get_local_lawmakers("55555")
    assert contacts
    assert all(contact.email for contact in contacts)


def test_generate_issue_message_includes_subject_and_lawmaker():
    lawmaker = LawmakerContact(
        name="Alex Doe",
        office="City Council",
        email="alex@example.gov",
    )
    message = generate_issue_message(
        lawmaker=lawmaker,
        subject="Transit reliability",
        user_concern="Please prioritize evening bus frequency improvements.",
    )
    assert "Alex Doe" in message
    assert "Transit reliability" in message
    assert "evening bus frequency" in message


def test_subject_store_aggregates_duplicates(tmp_path: Path):
    store = tmp_path / "subjects.json"
    add_subject("Public transit reliability", str(store))
    add_subject("public transit reliability", str(store))
    add_subject("Healthcare access", str(store))
    subjects = list_subjects(str(store))

    assert subjects[0]["subject"] in {
        "Public transit reliability",
        "public transit reliability",
    }
    assert subjects[0]["count"] == 2
    assert subjects[1]["subject"] == "Healthcare access"
    assert subjects[1]["count"] == 1
