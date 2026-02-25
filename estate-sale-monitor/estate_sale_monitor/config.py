"""Configuration loading and validation for estate-sale-monitor."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import List, Optional

import yaml


@dataclass
class LocationFilter:
    """Geographic filter for estate sale searches."""

    zip_code: str = ""
    radius_miles: int = 25

    @classmethod
    def from_dict(cls, data: dict) -> "LocationFilter":
        return cls(
            zip_code=str(data.get("zip_code", "")),
            radius_miles=int(data.get("radius_miles", 25)),
        )


@dataclass
class AlertConfig:
    """A single alert definition."""

    name: str
    keywords: List[str] = field(default_factory=list)
    category: str = ""
    max_price: Optional[float] = None
    min_price: Optional[float] = None
    location: Optional[LocationFilter] = None
    match_threshold: float = 0.3

    @classmethod
    def from_dict(cls, data: dict) -> "AlertConfig":
        location = None
        if "location" in data:
            location = LocationFilter.from_dict(data["location"])
        return cls(
            name=data["name"],
            keywords=[str(k).lower() for k in data.get("keywords", [])],
            category=str(data.get("category", "")).lower(),
            max_price=float(data["max_price"]) if "max_price" in data else None,
            min_price=float(data["min_price"]) if "min_price" in data else None,
            location=location,
            match_threshold=float(data.get("match_threshold", 0.3)),
        )


@dataclass
class NotificationConfig:
    """Notification/alerting delivery settings."""

    method: str = "file"  # "email" or "file"
    email: str = ""
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""

    @classmethod
    def from_dict(cls, data: dict) -> "NotificationConfig":
        return cls(
            method=str(data.get("method", "file")),
            email=str(data.get("email", "")),
            smtp_host=str(data.get("smtp_host", "smtp.gmail.com")),
            smtp_port=int(data.get("smtp_port", 587)),
            smtp_user=str(data.get("smtp_user", "")),
            smtp_password=str(data.get("smtp_password", "")),
        )


@dataclass
class Config:
    """Top-level configuration object."""

    alerts: List[AlertConfig] = field(default_factory=list)
    notification: NotificationConfig = field(default_factory=NotificationConfig)
    output_dir: str = "./matches"

    @classmethod
    def from_dict(cls, data: dict) -> "Config":
        alerts = [AlertConfig.from_dict(a) for a in data.get("alerts", [])]
        notification = NotificationConfig.from_dict(data.get("notification", {}))
        return cls(
            alerts=alerts,
            notification=notification,
            output_dir=str(data.get("output_dir", "./matches")),
        )


def load_config(path: str) -> Config:
    """Load and validate a YAML configuration file.

    Args:
        path: Filesystem path to the YAML config file.

    Returns:
        Validated :class:`Config` object.

    Raises:
        FileNotFoundError: If *path* does not exist.
        ValueError: If the configuration is missing required fields.
    """
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Config file not found: {path}")

    with open(path, encoding="utf-8") as fh:
        raw = yaml.safe_load(fh) or {}

    if "alerts" not in raw or not raw["alerts"]:
        raise ValueError("Configuration must define at least one alert.")

    for alert in raw["alerts"]:
        if "name" not in alert:
            raise ValueError("Each alert must have a 'name' field.")
        if not alert.get("keywords") and not alert.get("category"):
            raise ValueError(
                f"Alert '{alert['name']}' must have at least one keyword or a category."
            )

    return Config.from_dict(raw)
