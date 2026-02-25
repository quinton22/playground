"""Tests for the config module."""

import os
import tempfile

import pytest
import yaml

from estate_sale_monitor.config import (
    AlertConfig,
    Config,
    LocationFilter,
    NotificationConfig,
    load_config,
)


def _write_config(data: dict) -> str:
    """Write a YAML config to a temp file and return its path."""
    fd, path = tempfile.mkstemp(suffix=".yaml")
    with os.fdopen(fd, "w") as fh:
        yaml.dump(data, fh)
    return path


class TestAlertConfig:
    def test_from_dict_minimal(self):
        data = {"name": "Test", "keywords": ["camera"]}
        alert = AlertConfig.from_dict(data)
        assert alert.name == "Test"
        assert alert.keywords == ["camera"]
        assert alert.max_price is None
        assert alert.location is None

    def test_from_dict_keywords_lowercased(self):
        data = {"name": "Test", "keywords": ["Antique", "VICTORIAN"]}
        alert = AlertConfig.from_dict(data)
        assert alert.keywords == ["antique", "victorian"]

    def test_from_dict_with_location(self):
        data = {
            "name": "Local",
            "keywords": ["lamp"],
            "location": {"zip_code": "12345", "radius_miles": 10},
        }
        alert = AlertConfig.from_dict(data)
        assert alert.location is not None
        assert alert.location.zip_code == "12345"
        assert alert.location.radius_miles == 10

    def test_from_dict_with_price(self):
        data = {"name": "Cheap", "keywords": ["vase"], "max_price": 50, "min_price": 5}
        alert = AlertConfig.from_dict(data)
        assert alert.max_price == 50.0
        assert alert.min_price == 5.0

    def test_from_dict_custom_threshold(self):
        data = {"name": "T", "keywords": ["x"], "match_threshold": 0.7}
        alert = AlertConfig.from_dict(data)
        assert alert.match_threshold == 0.7


class TestLocationFilter:
    def test_defaults(self):
        loc = LocationFilter.from_dict({})
        assert loc.zip_code == ""
        assert loc.radius_miles == 25

    def test_custom(self):
        loc = LocationFilter.from_dict({"zip_code": "90210", "radius_miles": 50})
        assert loc.zip_code == "90210"
        assert loc.radius_miles == 50


class TestNotificationConfig:
    def test_defaults(self):
        cfg = NotificationConfig.from_dict({})
        assert cfg.method == "file"
        assert cfg.smtp_port == 587

    def test_email_method(self):
        data = {"method": "email", "email": "a@b.com", "smtp_user": "u", "smtp_password": "p"}
        cfg = NotificationConfig.from_dict(data)
        assert cfg.method == "email"
        assert cfg.email == "a@b.com"


class TestLoadConfig:
    def test_valid_config(self):
        data = {
            "alerts": [{"name": "Cameras", "keywords": ["camera"]}],
            "output_dir": "/tmp/out",
        }
        path = _write_config(data)
        try:
            config = load_config(path)
            assert len(config.alerts) == 1
            assert config.alerts[0].name == "Cameras"
            assert config.output_dir == "/tmp/out"
        finally:
            os.unlink(path)

    def test_missing_file(self):
        with pytest.raises(FileNotFoundError):
            load_config("/nonexistent/path/config.yaml")

    def test_no_alerts(self):
        data = {"alerts": []}
        path = _write_config(data)
        try:
            with pytest.raises(ValueError, match="at least one alert"):
                load_config(path)
        finally:
            os.unlink(path)

    def test_alert_missing_name(self):
        data = {"alerts": [{"keywords": ["camera"]}]}
        path = _write_config(data)
        try:
            with pytest.raises(ValueError, match="name"):
                load_config(path)
        finally:
            os.unlink(path)

    def test_alert_missing_keywords_and_category(self):
        data = {"alerts": [{"name": "Empty"}]}
        path = _write_config(data)
        try:
            with pytest.raises(ValueError, match="keyword"):
                load_config(path)
        finally:
            os.unlink(path)

    def test_multiple_alerts(self):
        data = {
            "alerts": [
                {"name": "A", "keywords": ["lamp"]},
                {"name": "B", "category": "furniture"},
            ]
        }
        path = _write_config(data)
        try:
            config = load_config(path)
            assert len(config.alerts) == 2
        finally:
            os.unlink(path)
