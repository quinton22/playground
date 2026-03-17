"""Services for the civic issues web experience."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

import requests


@dataclass(frozen=True)
class LawmakerContact:
    """Represents a local lawmaker contact option."""

    name: str
    office: str
    email: str


CURRENT_SUBJECTS = [
    "Housing affordability",
    "Education funding",
    "Healthcare access",
    "Climate resilience",
    "Public transit reliability",
    "Small business support",
]


_FALLBACK_BY_ZIP_PREFIX: dict[str, list[LawmakerContact]] = {
    "10": [
        LawmakerContact(
            name="New York City Council District Office",
            office="City Council",
            email="districtoffice@council.nyc.gov",
        ),
        LawmakerContact(
            name="New York State Senate Constituent Services",
            office="State Senate",
            email="constituent.services@nysenate.gov",
        ),
    ],
    "90": [
        LawmakerContact(
            name="Los Angeles City Council Office",
            office="City Council",
            email="councilmember.office@lacity.org",
        ),
        LawmakerContact(
            name="California State Senate Constituent Services",
            office="State Senate",
            email="senate.constituent@sen.ca.gov",
        ),
    ],
}

_DEFAULT_FALLBACK = [
    LawmakerContact(
        name="Local City Council Office",
        office="City Council",
        email="citycouncil@example.gov",
    ),
    LawmakerContact(
        name="State Representative Office",
        office="State Legislature",
        email="state.rep@example.gov",
    ),
]


def _google_civic_contacts(zip_code: str) -> list[LawmakerContact]:
    api_key = os.getenv("GOOGLE_CIVIC_API_KEY", "").strip()
    if not api_key:
        return []
    query = urlencode({"address": zip_code, "key": api_key})
    url = f"https://www.googleapis.com/civicinfo/v2/representatives?{query}"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    payload = response.json()
    offices = payload.get("offices", [])
    officials: list[dict[str, Any]] = payload.get("officials", [])
    index_to_office: dict[int, str] = {}
    for office in offices:
        office_name = office.get("name", "Public Office")
        for idx in office.get("officialIndices", []):
            index_to_office[idx] = office_name
    contacts: list[LawmakerContact] = []
    for idx, official in enumerate(officials):
        emails = official.get("emails", [])
        if not emails:
            continue
        contacts.append(
            LawmakerContact(
                name=official.get("name", "Local Official"),
                office=index_to_office.get(idx, "Public Office"),
                email=emails[0],
            )
        )
    return contacts


def get_local_lawmakers(zip_code: str) -> list[LawmakerContact]:
    """Return local lawmaker contacts with email addresses."""
    normalized = "".join(ch for ch in zip_code if ch.isdigit())
    if not normalized:
        return _DEFAULT_FALLBACK
    try:
        contacts = _google_civic_contacts(normalized)
        if contacts:
            return contacts
    except requests.RequestException:
        pass
    return _FALLBACK_BY_ZIP_PREFIX.get(normalized[:2], _DEFAULT_FALLBACK)


def generate_issue_message(
    lawmaker: LawmakerContact,
    subject: str,
    user_concern: str,
) -> str:
    """Generate an AI-style draft message on a current issue."""
    normalized_subject = subject.strip() or "community concerns"
    concern = user_concern.strip() or "I would appreciate your leadership on this issue."
    current_date = datetime.now(UTC).strftime("%Y-%m-%d")
    return (
        f"Subject: Support needed on {normalized_subject}\n\n"
        f"Dear {lawmaker.name},\n\n"
        f"I am a constituent writing about {normalized_subject}. "
        f"This topic is highly relevant today, alongside issues like "
        f"{', '.join(CURRENT_SUBJECTS[:3]).lower()}.\n\n"
        f"{concern}\n\n"
        "Please share what actions your office is taking and how residents can stay involved.\n\n"
        f"Sincerely,\nConcerned Resident\n\nDraft generated on {current_date}."
    )


def _load_subject_store(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    if not isinstance(payload, list):
        return []
    return [item for item in payload if isinstance(item, dict)]


def add_subject(subject: str, store_path: str) -> None:
    """Store user-submitted subject and aggregate counts."""
    normalized = subject.strip()
    if not normalized:
        return
    path = Path(store_path)
    entries = _load_subject_store(path)
    key = normalized.lower()
    now = datetime.now(UTC).isoformat()
    for entry in entries:
        if entry.get("key") == key:
            entry["count"] = int(entry.get("count", 1)) + 1
            entry["updated_at"] = now
            break
    else:
        entries.append(
            {
                "key": key,
                "subject": normalized,
                "count": 1,
                "updated_at": now,
            }
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(entries, fh, indent=2)


def list_subjects(store_path: str) -> list[dict[str, Any]]:
    """List user-submitted subjects sorted by popularity."""
    entries = _load_subject_store(Path(store_path))
    sorted_entries = sorted(
        entries,
        key=lambda item: (int(item.get("count", 0)), item.get("updated_at", "")),
        reverse=True,
    )
    return [
        {"subject": item.get("subject", ""), "count": int(item.get("count", 0))}
        for item in sorted_entries
        if item.get("subject")
    ]
