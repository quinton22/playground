"""Tests for the alerter module."""

import json
import os

import pytest

from estate_sale_monitor.alerter import dispatch_alert, send_file_alert
from estate_sale_monitor.config import NotificationConfig
from estate_sale_monitor.scraper import SaleItem


def _make_items(n: int = 2) -> list:
    return [
        SaleItem(
            title=f"Item {i}",
            price=float(10 * (i + 1)),
            sale_url="https://example.com/sale",
            sale_name="Test Sale",
            location="Springfield, IL",
        )
        for i in range(n)
    ]


class TestSendFileAlert:
    def test_creates_json_file(self, tmp_path):
        items = _make_items(2)
        path = send_file_alert(items, "My Alert", str(tmp_path))
        assert os.path.isfile(path)
        with open(path) as fh:
            data = json.load(fh)
        assert len(data) == 2
        assert data[0]["title"] == "Item 0"
        assert data[0]["alert"] == "My Alert"

    def test_appends_to_existing_file(self, tmp_path):
        items1 = _make_items(1)
        send_file_alert(items1, "Alert A", str(tmp_path))
        items2 = _make_items(2)
        path = send_file_alert(items2, "Alert B", str(tmp_path))
        with open(path) as fh:
            data = json.load(fh)
        assert len(data) == 3

    def test_creates_output_dir(self, tmp_path):
        nested = str(tmp_path / "a" / "b" / "c")
        items = _make_items(1)
        send_file_alert(items, "Test", nested)
        assert os.path.isdir(nested)

    def test_price_recorded(self, tmp_path):
        items = [SaleItem(title="Lamp", price=99.99, sale_url="http://x.com")]
        send_file_alert(items, "Lights", str(tmp_path))
        with open(os.path.join(str(tmp_path), "matches.json")) as fh:
            data = json.load(fh)
        assert data[0]["price"] == 99.99


class TestDispatchAlert:
    def test_dispatch_file_method(self, tmp_path):
        cfg = NotificationConfig(method="file")
        items = _make_items(1)
        dispatch_alert(items, "Test", cfg, str(tmp_path))
        assert os.path.isfile(str(tmp_path / "matches.json"))

    def test_dispatch_empty_matches_does_nothing(self, tmp_path):
        cfg = NotificationConfig(method="file")
        dispatch_alert([], "Test", cfg, str(tmp_path))
        assert not os.path.exists(str(tmp_path / "matches.json"))

    def test_dispatch_email_falls_back_to_file_on_failure(self, tmp_path):
        cfg = NotificationConfig(
            method="email",
            email="",  # missing email → send_email_alert returns False
            smtp_user="",
        )
        items = _make_items(1)
        dispatch_alert(items, "Test", cfg, str(tmp_path))
        # Should have fallen back to file output
        assert os.path.isfile(str(tmp_path / "matches.json"))
