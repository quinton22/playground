"""Alert delivery: email and file-based notifications."""

from __future__ import annotations

import json
import logging
import os
import smtplib
from dataclasses import asdict
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import List

from .config import NotificationConfig
from .scraper import SaleItem

logger = logging.getLogger(__name__)


def _item_to_dict(item: SaleItem, alert_name: str) -> dict:
    return {
        "alert": alert_name,
        "title": item.title,
        "description": item.description,
        "price": item.price,
        "sale_url": item.sale_url,
        "sale_name": item.sale_name,
        "location": item.location,
        "image_urls": item.image_urls,
    }


def send_file_alert(
    matches: List[SaleItem],
    alert_name: str,
    output_dir: str,
) -> str:
    """Append matching items to a JSON results file.

    Args:
        matches: Items that matched the alert.
        alert_name: Human-readable name of the alert.
        output_dir: Directory where the results file will be written.

    Returns:
        Path to the results file.
    """
    os.makedirs(output_dir, exist_ok=True)
    results_path = os.path.join(output_dir, "matches.json")

    existing: List[dict] = []
    if os.path.isfile(results_path):
        try:
            with open(results_path, encoding="utf-8") as fh:
                existing = json.load(fh)
        except (json.JSONDecodeError, OSError):
            existing = []

    new_records = [_item_to_dict(item, alert_name) for item in matches]
    combined = existing + new_records

    with open(results_path, "w", encoding="utf-8") as fh:
        json.dump(combined, fh, indent=2)

    logger.info(
        "Saved %d match(es) for alert '%s' to %s", len(matches), alert_name, results_path
    )
    return results_path


def send_email_alert(
    matches: List[SaleItem],
    alert_name: str,
    config: NotificationConfig,
) -> bool:
    """Send an email notification with matching items.

    Args:
        matches: Items that matched the alert.
        alert_name: Human-readable name of the alert.
        config: :class:`NotificationConfig` with SMTP credentials.

    Returns:
        ``True`` if the email was sent successfully, ``False`` otherwise.
    """
    if not config.email or not config.smtp_user:
        logger.warning("Email notification skipped: missing email or SMTP credentials.")
        return False

    subject = f"[Estate Sale Monitor] {len(matches)} match(es) for '{alert_name}'"
    lines = [f"<h2>Matches for alert: {alert_name}</h2>", "<ul>"]
    for item in matches:
        price_str = f"${item.price:.2f}" if item.price is not None else "price unknown"
        lines.append(
            f"<li><strong>{item.title}</strong> — {price_str}<br>"
            f"Sale: <a href='{item.sale_url}'>{item.sale_name or item.sale_url}</a><br>"
            f"Location: {item.location}</li>"
        )
    lines.append("</ul>")
    body_html = "\n".join(lines)

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = config.smtp_user
    msg["To"] = config.email
    msg.attach(MIMEText(body_html, "html"))

    try:
        with smtplib.SMTP(config.smtp_host, config.smtp_port) as server:
            server.ehlo()
            server.starttls()
            server.login(config.smtp_user, config.smtp_password)
            server.sendmail(config.smtp_user, [config.email], msg.as_string())
        logger.info("Email alert sent to %s for alert '%s'", config.email, alert_name)
        return True
    except smtplib.SMTPException as exc:
        logger.error("Failed to send email alert: %s", exc)
        return False


def dispatch_alert(
    matches: List[SaleItem],
    alert_name: str,
    config: NotificationConfig,
    output_dir: str = "./matches",
) -> None:
    """Route the alert to the configured delivery method.

    Args:
        matches: Items that matched the alert.
        alert_name: Human-readable name of the alert.
        config: Notification configuration.
        output_dir: Fallback output directory when method is ``"file"``.
    """
    if not matches:
        return

    if config.method == "email":
        success = send_email_alert(matches, alert_name, config)
        if not success:
            logger.warning("Email failed; falling back to file output.")
            send_file_alert(matches, alert_name, output_dir)
    else:
        send_file_alert(matches, alert_name, output_dir)
