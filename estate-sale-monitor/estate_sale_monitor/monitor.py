"""Main monitor orchestrator: ties scraping, analysis, and alerting together."""

from __future__ import annotations

import logging
import os
from typing import List, Optional

import requests

from .alerter import dispatch_alert
from .config import AlertConfig, Config
from .image_analyzer import ImageFeatures, analyze_image_bytes, score_image
from .scraper import (
    EstateSale,
    SaleItem,
    _make_session,
    download_image,
    scrape_sale,
    search_sales,
)

logger = logging.getLogger(__name__)


def _matches_alert(item: SaleItem, alert: AlertConfig) -> bool:
    """Return ``True`` if *item* satisfies the textual/price criteria of *alert*."""
    if alert.max_price is not None and item.price is not None:
        if item.price > alert.max_price:
            return False
    if alert.min_price is not None and item.price is not None:
        if item.price < alert.min_price:
            return False

    text = item.keyword_text()
    if alert.keywords:
        if not any(kw in text for kw in alert.keywords):
            return False
    if alert.category and alert.category not in text:
        return False

    return True


def _image_matches_alert(
    features: ImageFeatures, alert: AlertConfig
) -> bool:
    """Return ``True`` if image *features* exceed the alert's match threshold."""
    score = score_image(features, alert.keywords)
    return score >= alert.match_threshold


def run_once(
    config: Config,
    url: Optional[str] = None,
    site: Optional[str] = None,
) -> None:
    """Execute one monitoring pass.

    If *url* is provided, that specific sale page is scraped.  Otherwise, all
    configured alerts are used to drive searches across the supported sites.

    Args:
        config: Loaded :class:`Config` object.
        url: Optional specific sale URL to scrape directly.
        site: Limit searches to one site key.
    """
    session = _make_session()
    output_dir = config.output_dir
    os.makedirs(output_dir, exist_ok=True)

    for alert in config.alerts:
        logger.info("Processing alert: %s", alert.name)
        matched_items: List[SaleItem] = []

        if url:
            # Scrape a specific sale URL
            items = scrape_sale(url, session)
            sales: List[EstateSale] = []
        else:
            # Search across sites for this alert
            zip_code = alert.location.zip_code if alert.location else ""
            radius = alert.location.radius_miles if alert.location else 25
            sales = search_sales(
                keywords=alert.keywords or [alert.category],
                zip_code=zip_code,
                radius=radius,
                site=site,
                session=session,
            )
            items = []

        # Scrape each found sale for items
        for sale in sales:
            sale_items = scrape_sale(sale.url, session)
            for it in sale_items:
                it.sale_name = sale.name
                it.location = sale.location
            items.extend(sale_items)

        # Filter items by text/price criteria
        candidate_items = [it for it in items if _matches_alert(it, alert)]
        logger.info(
            "Alert '%s': %d candidate item(s) after text filter", alert.name, len(candidate_items)
        )

        for item in candidate_items:
            # Attempt image-based analysis for items that have images
            image_matched = False
            for img_url in item.image_urls:
                try:
                    resp = session.get(img_url, timeout=15)
                    resp.raise_for_status()
                    features = analyze_image_bytes(resp.content)
                    if features is not None:
                        if _image_matches_alert(features, alert):
                            image_matched = True
                            # Save the image locally
                            img_filename = img_url.split("/")[-1].split("?")[0] or "image.jpg"
                            img_dest = os.path.join(output_dir, img_filename)
                            if not os.path.exists(img_dest):
                                download_image(img_url, img_dest, session)
                        break  # only analyze the first image per item
                except Exception as exc:  # pylint: disable=broad-except
                    logger.debug("Image fetch failed for %s: %s", img_url, exc)

            # Include item if it matched by text (no images available) or image analysis
            if not item.image_urls or image_matched:
                matched_items.append(item)

        logger.info("Alert '%s': %d final match(es)", alert.name, len(matched_items))
        if matched_items:
            dispatch_alert(matched_items, alert.name, config.notification, output_dir)
