"""Command-line interface for estate-sale-monitor."""

from __future__ import annotations

import argparse
import logging
import sys
import time

import schedule

from .config import load_config
from .monitor import run_once
from .scraper import SUPPORTED_SITES


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="estate-sale-monitor",
        description=(
            "Monitor estate sale websites and send alerts when items "
            "matching your configured queries are found."
        ),
    )
    parser.add_argument(
        "--config",
        required=True,
        metavar="CONFIG",
        help="Path to YAML alert configuration file.",
    )
    parser.add_argument(
        "--url",
        default=None,
        metavar="URL",
        help="Scrape a specific estate sale URL instead of searching.",
    )
    parser.add_argument(
        "--site",
        default=None,
        choices=list(SUPPORTED_SITES),
        metavar="SITE",
        help=(
            "Limit monitoring to a specific site "
            f"({', '.join(SUPPORTED_SITES)})."
        ),
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=None,
        metavar="HOURS",
        help="Run repeatedly every HOURS hours (omit for a single run).",
    )
    parser.add_argument(
        "--output",
        default=None,
        metavar="DIR",
        help="Directory to save matched images and results (overrides config).",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose (DEBUG) logging.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    try:
        config = load_config(args.config)
    except (FileNotFoundError, ValueError) as exc:
        print(f"Error loading config: {exc}", file=sys.stderr)
        return 1

    if args.output:
        config.output_dir = args.output

    def _run() -> None:
        run_once(config, url=args.url, site=args.site)

    if args.interval:
        schedule.every(args.interval).hours.do(_run)
        logging.getLogger(__name__).info(
            "Scheduled to run every %.1f hour(s). Press Ctrl+C to stop.", args.interval
        )
        _run()  # run immediately on start
        try:
            while True:
                schedule.run_pending()
                time.sleep(60)
        except KeyboardInterrupt:
            pass
    else:
        _run()

    return 0


if __name__ == "__main__":
    sys.exit(main())
