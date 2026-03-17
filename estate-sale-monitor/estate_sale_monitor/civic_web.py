"""Simple web UI for civic outreach workflows."""

from __future__ import annotations

import argparse
import html
import os
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

from .civic_service import (
    add_subject,
    generate_issue_message,
    get_local_lawmakers,
    list_subjects,
)


def _render_page(
    zip_code: str,
    subject: str,
    details: str,
    lawmakers_html: str,
    messages_html: str,
    subjects_html: str,
) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Civic Message Hub</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 2rem auto; max-width: 960px; line-height: 1.5; }}
    form {{ border: 1px solid #ddd; border-radius: 8px; padding: 1rem; background: #fafafa; }}
    label {{ display: block; margin-top: .75rem; font-weight: 600; }}
    input, textarea {{ width: 100%; padding: .5rem; margin-top: .25rem; }}
    button {{ margin-top: .75rem; padding: .6rem .9rem; }}
    .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-top: 1rem; }}
    .card {{ border: 1px solid #ddd; border-radius: 8px; padding: .75rem; }}
    pre {{ white-space: pre-wrap; background: #111; color: #f5f5f5; padding: .75rem; border-radius: 6px; }}
    @media (max-width: 768px) {{ .grid {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
  <h1>Civic Message Hub</h1>
  <p>Find local lawmakers' email contacts, draft issue messages, and see subjects submitted by other users.</p>
  <form method="post" action="/">
    <label for="zip_code">ZIP code</label>
    <input id="zip_code" name="zip_code" value="{html.escape(zip_code)}" placeholder="e.g. 10001" />
    <label for="subject">Issue subject</label>
    <input id="subject" name="subject" value="{html.escape(subject)}" placeholder="e.g. Housing affordability" />
    <label for="details">Your talking points</label>
    <textarea id="details" name="details" rows="5" placeholder="What specific change do you want?">{html.escape(details)}</textarea>
    <button type="submit">Find contacts and generate messages</button>
  </form>

  <div class="grid">
    <section class="card">
      <h2>Local lawmakers</h2>
      {lawmakers_html}
    </section>
    <section class="card">
      <h2>Shared subjects from users</h2>
      {subjects_html}
    </section>
  </div>

  <section class="card" style="margin-top:1rem;">
    <h2>AI-assisted draft messages</h2>
    {messages_html}
  </section>
</body>
</html>
"""


def make_handler(subject_store_path: str):
    class CivicHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            if self.path != "/":
                self.send_error(HTTPStatus.NOT_FOUND, "Not Found")
                return
            shared = list_subjects(subject_store_path)
            subjects_html = _subjects_to_html(shared)
            payload = _render_page("", "", "", "<p>Submit the form to load contacts.</p>", "", subjects_html)
            self._write_html(payload)

        def do_POST(self) -> None:  # noqa: N802
            if self.path != "/":
                self.send_error(HTTPStatus.NOT_FOUND, "Not Found")
                return
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length).decode("utf-8")
            data = parse_qs(raw)
            zip_code = data.get("zip_code", [""])[0]
            subject = data.get("subject", [""])[0]
            details = data.get("details", [""])[0]

            add_subject(subject, subject_store_path)
            lawmakers = get_local_lawmakers(zip_code)
            lawmakers_html = _lawmakers_to_html(lawmakers)
            messages_html = _messages_to_html(lawmakers, subject, details)
            subjects_html = _subjects_to_html(list_subjects(subject_store_path))
            payload = _render_page(
                zip_code=zip_code,
                subject=subject,
                details=details,
                lawmakers_html=lawmakers_html,
                messages_html=messages_html,
                subjects_html=subjects_html,
            )
            self._write_html(payload)

        def log_message(self, format: str, *args) -> None:  # noqa: A003
            return

        def _write_html(self, payload: str) -> None:
            encoded = payload.encode("utf-8")
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

    return CivicHandler


def _lawmakers_to_html(lawmakers) -> str:
    if not lawmakers:
        return "<p>No contacts found.</p>"
    lines = [
        "<ul>",
        *[
            (
                "<li><strong>"
                f"{html.escape(lawmaker.name)}</strong> — {html.escape(lawmaker.office)}"
                f"<br /><a href='mailto:{html.escape(lawmaker.email)}'>{html.escape(lawmaker.email)}</a></li>"
            )
            for lawmaker in lawmakers
        ],
        "</ul>",
    ]
    return "".join(lines)


def _messages_to_html(lawmakers, subject: str, details: str) -> str:
    if not lawmakers:
        return "<p>No message drafts yet.</p>"
    blocks = []
    for lawmaker in lawmakers:
        message = generate_issue_message(lawmaker, subject, details)
        blocks.append(
            f"<h3>{html.escape(lawmaker.name)}</h3><pre>{html.escape(message)}</pre>"
        )
    return "".join(blocks)


def _subjects_to_html(subjects) -> str:
    if not subjects:
        return "<p>No user subjects yet. Be the first to submit one.</p>"
    items = "".join(
        f"<li>{html.escape(item['subject'])} <small>({item['count']} submissions)</small></li>"
        for item in subjects
    )
    return f"<ul>{items}</ul>"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="civic-message-web",
        description="Run the civic message website locally.",
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument(
        "--subjects-file",
        default=os.path.join(os.getcwd(), "shared_subjects.json"),
        help="File path used to store shared user subjects.",
    )
    args = parser.parse_args(argv)

    server = ThreadingHTTPServer(
        (args.host, args.port),
        make_handler(args.subjects_file),
    )
    print(f"Civic Message Hub running on http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
