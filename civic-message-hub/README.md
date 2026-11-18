# Civic Message Hub

A lightweight website that helps users find local lawmaker/politician email contacts, generate issue-focused outreach drafts, and share issue subjects with other users.

## Features

- Finds local lawmaker/politician contact emails by ZIP code
- Generates AI-style outreach draft messages for current/relevant community issues
- Collects user-submitted issue subjects and displays them to other users

## Usage

Install and run the website locally:

```bash
pip install -e .
civic-message-web --host 127.0.0.1 --port 8000
```

Then open `http://127.0.0.1:8000` in your browser.

## Optional: Google Civic API

Set `GOOGLE_CIVIC_API_KEY` to retrieve live representative data from the Google Civic Information API. Without it, fallback local contacts are used for common ZIP code prefixes.

```bash
export GOOGLE_CIVIC_API_KEY=your_api_key_here
civic-message-web
```

## Python API

```python
from civic_message_hub.civic_service import get_local_lawmakers, generate_issue_message

lawmakers = get_local_lawmakers("10001")
draft = generate_issue_message(
    lawmakers[0],
    "Housing affordability",
    "Please support renter protections and more affordable units.",
)
```

## Running Tests

```bash
pip install -e .
python -m pytest tests/
```

## Requirements

- Python 3.9+
- `requests` library
