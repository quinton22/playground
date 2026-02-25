"""Web scraper for estate sale listing sites."""

from __future__ import annotations

import logging
import re
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

# Polite delay between requests (seconds)
_REQUEST_DELAY = 1.5

SUPPORTED_SITES = ("estatesales", "gsalr", "estatesalesorg")


@dataclass
class SaleItem:
    """Represents a single item listing found at an estate sale."""

    title: str
    description: str = ""
    price: Optional[float] = None
    image_urls: List[str] = field(default_factory=list)
    sale_url: str = ""
    sale_name: str = ""
    location: str = ""

    def keyword_text(self) -> str:
        """Return all textual content concatenated for keyword matching."""
        return " ".join([self.title, self.description, self.sale_name]).lower()


@dataclass
class EstateSale:
    """Represents a single estate sale event."""

    name: str
    url: str
    location: str = ""
    items: List[SaleItem] = field(default_factory=list)


def _get(url: str, session: requests.Session, timeout: int = 15) -> Optional[BeautifulSoup]:
    """Perform a GET request and return a parsed BeautifulSoup document."""
    try:
        time.sleep(_REQUEST_DELAY)
        resp = session.get(url, timeout=timeout)
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml")
    except requests.RequestException as exc:
        logger.warning("Request failed for %s: %s", url, exc)
        return None


def _make_session(headers: Optional[Dict[str, str]] = None) -> requests.Session:
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "Mozilla/5.0 (compatible; EstateSaleMonitorBot/1.0; "
                "+https://github.com/quinton22/playground)"
            ),
            **(headers or {}),
        }
    )
    return session


# ---------------------------------------------------------------------------
# EstateSales.NET scraper
# ---------------------------------------------------------------------------

def _scrape_estatesales_search(
    keywords: List[str],
    zip_code: str = "",
    radius: int = 25,
    session: Optional[requests.Session] = None,
) -> List[EstateSale]:
    """Search EstateSales.NET for sales matching *keywords*."""
    session = session or _make_session()
    query = "+".join(keywords)
    params = f"?q={query}"
    if zip_code:
        params += f"&zip={zip_code}&radius={radius}"
    url = f"https://www.estatesales.net/search{params}"
    logger.info("Searching EstateSales.NET: %s", url)
    soup = _get(url, session)
    if soup is None:
        return []

    sales: List[EstateSale] = []
    for card in soup.select("a.sale-card, div.sale-listing a, li.sale-result a"):
        href = card.get("href", "")
        if not href:
            continue
        full_url = urljoin("https://www.estatesales.net", href)
        name_el = card.select_one(".sale-name, h2, h3, .title")
        location_el = card.select_one(".sale-location, .location, .city")
        sales.append(
            EstateSale(
                name=name_el.get_text(strip=True) if name_el else full_url,
                url=full_url,
                location=location_el.get_text(strip=True) if location_el else "",
            )
        )
    return sales


def _scrape_estatesales_sale(
    sale_url: str, session: Optional[requests.Session] = None
) -> List[SaleItem]:
    """Scrape item listings from a single EstateSales.NET sale page."""
    session = session or _make_session()
    logger.info("Scraping EstateSales.NET sale: %s", sale_url)
    soup = _get(sale_url, session)
    if soup is None:
        return []

    items: List[SaleItem] = []
    for card in soup.select("div.photo-item, div.item-card, li.catalog-item"):
        title_el = card.select_one(".item-title, .caption, h3, h4, p")
        price_el = card.select_one(".price, .item-price")
        img_el = card.select_one("img")

        title = title_el.get_text(strip=True) if title_el else ""
        price: Optional[float] = None
        if price_el:
            price_text = re.sub(r"[^\d.]", "", price_el.get_text())
            try:
                price = float(price_text)
            except ValueError:
                pass

        img_urls: List[str] = []
        if img_el:
            src = img_el.get("data-src") or img_el.get("src") or ""
            if src:
                img_urls.append(urljoin(sale_url, src))

        if title or img_urls:
            items.append(
                SaleItem(
                    title=title,
                    price=price,
                    image_urls=img_urls,
                    sale_url=sale_url,
                )
            )
    return items


# ---------------------------------------------------------------------------
# GSALR scraper
# ---------------------------------------------------------------------------

def _scrape_gsalr_search(
    keywords: List[str],
    zip_code: str = "",
    radius: int = 25,
    session: Optional[requests.Session] = None,
) -> List[EstateSale]:
    """Search GSALR for sales matching *keywords*."""
    session = session or _make_session()
    query = " ".join(keywords)
    params = {"q": query}
    if zip_code:
        params["zip"] = zip_code
        params["distance"] = str(radius)
    url = "https://gsalr.com/search"
    logger.info("Searching GSALR: %s params=%s", url, params)
    try:
        time.sleep(_REQUEST_DELAY)
        resp = session.get(url, params=params, timeout=15)
        resp.raise_for_status()
    except requests.RequestException as exc:
        logger.warning("GSALR search failed: %s", exc)
        return []

    soup = BeautifulSoup(resp.text, "lxml")
    sales: List[EstateSale] = []
    for card in soup.select("div.sale-result, li.sale, a.sale-link"):
        href = card.get("href") or ""
        if not href and card.name != "a":
            link = card.select_one("a")
            href = link.get("href", "") if link else ""
        if not href:
            continue
        full_url = urljoin("https://gsalr.com", href)
        name_el = card.select_one(".sale-title, h2, h3, .name")
        loc_el = card.select_one(".location, .city, .address")
        sales.append(
            EstateSale(
                name=name_el.get_text(strip=True) if name_el else full_url,
                url=full_url,
                location=loc_el.get_text(strip=True) if loc_el else "",
            )
        )
    return sales


def _scrape_gsalr_sale(
    sale_url: str, session: Optional[requests.Session] = None
) -> List[SaleItem]:
    """Scrape item listings from a single GSALR sale page."""
    session = session or _make_session()
    logger.info("Scraping GSALR sale: %s", sale_url)
    soup = _get(sale_url, session)
    if soup is None:
        return []

    items: List[SaleItem] = []
    for card in soup.select("div.item, li.item, div.photo"):
        title_el = card.select_one(".title, .caption, h3, p")
        img_el = card.select_one("img")
        title = title_el.get_text(strip=True) if title_el else ""
        img_urls: List[str] = []
        if img_el:
            src = img_el.get("data-src") or img_el.get("src") or ""
            if src:
                img_urls.append(urljoin(sale_url, src))
        if title or img_urls:
            items.append(SaleItem(title=title, image_urls=img_urls, sale_url=sale_url))
    return items


# ---------------------------------------------------------------------------
# EstateSales.org scraper
# ---------------------------------------------------------------------------

def _scrape_estatesalesorg_search(
    keywords: List[str],
    zip_code: str = "",
    radius: int = 25,
    session: Optional[requests.Session] = None,
) -> List[EstateSale]:
    """Search EstateSales.org for sales matching *keywords*."""
    session = session or _make_session()
    query = "+".join(keywords)
    url = f"https://estatesales.org/search?q={query}"
    if zip_code:
        url += f"&zip={zip_code}&miles={radius}"
    logger.info("Searching EstateSales.org: %s", url)
    soup = _get(url, session)
    if soup is None:
        return []

    sales: List[EstateSale] = []
    for card in soup.select("div.sale, li.sale, a.sale-link"):
        href = card.get("href") or ""
        if not href and card.name != "a":
            link = card.select_one("a")
            href = link.get("href", "") if link else ""
        if not href:
            continue
        full_url = urljoin("https://estatesales.org", href)
        name_el = card.select_one("h2, h3, .sale-name, .title")
        loc_el = card.select_one(".location, .city")
        sales.append(
            EstateSale(
                name=name_el.get_text(strip=True) if name_el else full_url,
                url=full_url,
                location=loc_el.get_text(strip=True) if loc_el else "",
            )
        )
    return sales


def _scrape_estatesalesorg_sale(
    sale_url: str, session: Optional[requests.Session] = None
) -> List[SaleItem]:
    """Scrape items from a single EstateSales.org sale page."""
    session = session or _make_session()
    logger.info("Scraping EstateSales.org sale: %s", sale_url)
    soup = _get(sale_url, session)
    if soup is None:
        return []

    items: List[SaleItem] = []
    for card in soup.select("div.item, li.item"):
        title_el = card.select_one(".title, h3, p")
        img_el = card.select_one("img")
        title = title_el.get_text(strip=True) if title_el else ""
        img_urls: List[str] = []
        if img_el:
            src = img_el.get("data-src") or img_el.get("src") or ""
            if src:
                img_urls.append(urljoin(sale_url, src))
        if title or img_urls:
            items.append(SaleItem(title=title, image_urls=img_urls, sale_url=sale_url))
    return items


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def _detect_site(url: str) -> str:
    """Return the site key for a given URL, or empty string if unknown."""
    host = urlparse(url).netloc.lower()
    if "estatesales.net" in host:
        return "estatesales"
    if "gsalr.com" in host:
        return "gsalr"
    if "estatesales.org" in host:
        return "estatesalesorg"
    return ""


def scrape_sale(url: str, session: Optional[requests.Session] = None) -> List[SaleItem]:
    """Scrape items from a specific estate sale URL.

    Args:
        url: Full URL of an estate sale listing page.
        session: Optional :class:`requests.Session` to reuse.

    Returns:
        List of :class:`SaleItem` objects found on the page.
    """
    site = _detect_site(url)
    session = session or _make_session()
    if site == "estatesales":
        return _scrape_estatesales_sale(url, session)
    if site == "gsalr":
        return _scrape_gsalr_sale(url, session)
    if site == "estatesalesorg":
        return _scrape_estatesalesorg_sale(url, session)
    # Generic fallback: collect all img tags
    logger.warning("Unknown site for URL %s — using generic scraper", url)
    soup = _get(url, session)
    if soup is None:
        return []
    items: List[SaleItem] = []
    for img in soup.find_all("img"):
        src = img.get("data-src") or img.get("src") or ""
        if src and src.startswith("http"):
            items.append(SaleItem(title=img.get("alt", ""), image_urls=[src], sale_url=url))
    return items


def search_sales(
    keywords: List[str],
    zip_code: str = "",
    radius: int = 25,
    site: Optional[str] = None,
    session: Optional[requests.Session] = None,
) -> List[EstateSale]:
    """Search all (or one) supported site(s) for estate sales.

    Args:
        keywords: List of search terms.
        zip_code: Optional ZIP code for geographic filtering.
        radius: Search radius in miles (used when *zip_code* is provided).
        site: Limit search to one site key (``"estatesales"``, ``"gsalr"``,
              ``"estatesalesorg"``).  ``None`` searches all sites.
        session: Optional :class:`requests.Session` to reuse.

    Returns:
        Combined list of :class:`EstateSale` objects.
    """
    session = session or _make_session()
    targets = [site] if site and site in SUPPORTED_SITES else list(SUPPORTED_SITES)
    results: List[EstateSale] = []
    for target in targets:
        try:
            if target == "estatesales":
                results.extend(
                    _scrape_estatesales_search(keywords, zip_code, radius, session)
                )
            elif target == "gsalr":
                results.extend(_scrape_gsalr_search(keywords, zip_code, radius, session))
            elif target == "estatesalesorg":
                results.extend(
                    _scrape_estatesalesorg_search(keywords, zip_code, radius, session)
                )
        except Exception as exc:  # pylint: disable=broad-except
            logger.error("Error searching %s: %s", target, exc)
    return results


def download_image(url: str, dest_path: str, session: Optional[requests.Session] = None) -> bool:
    """Download an image from *url* and save it to *dest_path*.

    Args:
        url: Remote image URL.
        dest_path: Local filesystem path to write the image data.
        session: Optional :class:`requests.Session` to reuse.

    Returns:
        ``True`` on success, ``False`` on failure.
    """
    session = session or _make_session()
    try:
        time.sleep(_REQUEST_DELAY)
        resp = session.get(url, timeout=20, stream=True)
        resp.raise_for_status()
        with open(dest_path, "wb") as fh:
            for chunk in resp.iter_content(chunk_size=8192):
                fh.write(chunk)
        return True
    except (requests.RequestException, OSError) as exc:
        logger.warning("Failed to download %s: %s", url, exc)
        return False
