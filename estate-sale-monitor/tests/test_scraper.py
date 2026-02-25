"""Tests for the scraper module."""

from unittest.mock import MagicMock, patch

import pytest

from estate_sale_monitor.scraper import (
    SaleItem,
    _detect_site,
    _make_session,
    download_image,
    scrape_sale,
    search_sales,
)


class TestSaleItem:
    def test_keyword_text(self):
        item = SaleItem(title="Victorian Dresser", description="Beautiful wood", sale_name="Big Sale")
        text = item.keyword_text()
        assert "victorian" in text
        assert "dresser" in text
        assert "beautiful wood" in text
        assert "big sale" in text

    def test_keyword_text_lowercase(self):
        item = SaleItem(title="ANTIQUE TABLE")
        assert "antique table" in item.keyword_text()


class TestDetectSite:
    def test_estatesales_net(self):
        assert _detect_site("https://www.estatesales.net/CA/1234") == "estatesales"

    def test_gsalr(self):
        assert _detect_site("https://gsalr.com/sales/1234") == "gsalr"

    def test_estatesalesorg(self):
        assert _detect_site("https://estatesales.org/sale/1234") == "estatesalesorg"

    def test_unknown(self):
        assert _detect_site("https://example.com/sale") == ""


class TestMakeSession:
    def test_user_agent_set(self):
        session = _make_session()
        assert "EstateSaleMonitorBot" in session.headers["User-Agent"]

    def test_custom_headers_merged(self):
        session = _make_session({"X-Custom": "value"})
        assert session.headers["X-Custom"] == "value"
        assert "EstateSaleMonitorBot" in session.headers["User-Agent"]


class TestScrapeSale:
    @patch("estate_sale_monitor.scraper._get")
    def test_unknown_site_generic_fallback(self, mock_get):
        from bs4 import BeautifulSoup

        html = '<html><body><img src="http://example.com/photo.jpg" alt="lamp"/></body></html>'
        mock_get.return_value = BeautifulSoup(html, "lxml")
        items = scrape_sale("https://unknown-site.com/sale/123")
        assert len(items) == 1
        assert items[0].image_urls == ["http://example.com/photo.jpg"]
        assert items[0].title == "lamp"

    @patch("estate_sale_monitor.scraper._get")
    def test_returns_empty_on_request_failure(self, mock_get):
        mock_get.return_value = None
        items = scrape_sale("https://www.estatesales.net/sale/123")
        assert items == []

    @patch("estate_sale_monitor.scraper._get")
    def test_estatesales_item_scraping(self, mock_get):
        from bs4 import BeautifulSoup

        html = """
        <html><body>
          <div class="photo-item">
            <p class="item-title">Antique Clock</p>
            <span class="price">$120</span>
            <img src="/images/clock.jpg"/>
          </div>
        </body></html>
        """
        mock_get.return_value = BeautifulSoup(html, "lxml")
        items = scrape_sale("https://www.estatesales.net/sale/999")
        assert len(items) == 1
        assert items[0].title == "Antique Clock"
        assert items[0].price == 120.0


class TestSearchSales:
    @patch("estate_sale_monitor.scraper._scrape_estatesales_search")
    @patch("estate_sale_monitor.scraper._scrape_gsalr_search")
    @patch("estate_sale_monitor.scraper._scrape_estatesalesorg_search")
    def test_searches_all_sites_by_default(self, mock_org, mock_gsalr, mock_es):
        mock_es.return_value = []
        mock_gsalr.return_value = []
        mock_org.return_value = []
        search_sales(["camera"])
        mock_es.assert_called_once()
        mock_gsalr.assert_called_once()
        mock_org.assert_called_once()

    @patch("estate_sale_monitor.scraper._scrape_estatesales_search")
    @patch("estate_sale_monitor.scraper._scrape_gsalr_search")
    @patch("estate_sale_monitor.scraper._scrape_estatesalesorg_search")
    def test_limits_to_specified_site(self, mock_org, mock_gsalr, mock_es):
        mock_es.return_value = []
        search_sales(["lamp"], site="estatesales")
        mock_es.assert_called_once()
        mock_gsalr.assert_not_called()
        mock_org.assert_not_called()

    @patch("estate_sale_monitor.scraper._scrape_estatesales_search", side_effect=RuntimeError("boom"))
    @patch("estate_sale_monitor.scraper._scrape_gsalr_search")
    @patch("estate_sale_monitor.scraper._scrape_estatesalesorg_search")
    def test_continues_on_site_error(self, mock_org, mock_gsalr, mock_es):
        mock_gsalr.return_value = []
        mock_org.return_value = []
        # Should not raise even though estatesales raises
        results = search_sales(["x"])
        assert results == []


class TestDownloadImage:
    @patch("estate_sale_monitor.scraper.time.sleep")
    def test_success(self, mock_sleep, tmp_path):
        dest = str(tmp_path / "img.jpg")
        mock_response = MagicMock()
        mock_response.raise_for_status = MagicMock()
        mock_response.iter_content = MagicMock(return_value=[b"fake_image_data"])

        session = MagicMock()
        session.get.return_value.__enter__ = lambda s: mock_response
        session.get.return_value.__exit__ = MagicMock(return_value=False)
        session.get.return_value = mock_response

        result = download_image("http://example.com/img.jpg", dest, session)
        assert result is True
        assert os.path.isfile(dest)

    def test_failure_returns_false(self, tmp_path):
        import requests as req

        dest = str(tmp_path / "img.jpg")
        session = MagicMock()
        session.get.side_effect = req.ConnectionError("no connection")
        result = download_image("http://example.com/img.jpg", dest, session)
        assert result is False


import os
