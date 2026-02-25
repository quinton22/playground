"""Tests for the image_analyzer module."""

import io
import os

import pytest

from estate_sale_monitor.image_analyzer import (
    ImageFeatures,
    analyze_image_bytes,
    analyze_image_file,
    score_image,
)

try:
    from PIL import Image
    _PIL_AVAILABLE = True
except ImportError:
    _PIL_AVAILABLE = False

pytestmark = pytest.mark.skipif(not _PIL_AVAILABLE, reason="Pillow not installed")


def _make_jpeg_bytes(color: tuple = (128, 64, 32), size: tuple = (50, 50)) -> bytes:
    """Return raw JPEG bytes of a solid-color image."""
    img = Image.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def _make_png_file(path: str, color: tuple = (200, 100, 50), size: tuple = (30, 30)) -> None:
    img = Image.new("RGB", size, color=color)
    img.save(path, format="PNG")


class TestAnalyzeImageBytes:
    def test_returns_features(self):
        data = _make_jpeg_bytes()
        features = analyze_image_bytes(data)
        assert features is not None
        assert isinstance(features, ImageFeatures)

    def test_dimensions(self):
        data = _make_jpeg_bytes(size=(100, 80))
        features = analyze_image_bytes(data)
        assert features.width == 100
        assert features.height == 80

    def test_dominant_colors_populated(self):
        data = _make_jpeg_bytes(color=(255, 0, 0))
        features = analyze_image_bytes(data)
        assert features.dominant_colors  # should have at least one color

    def test_brightness_in_range(self):
        data = _make_jpeg_bytes(color=(200, 200, 200))
        features = analyze_image_bytes(data)
        # Grayscale brightness of (200, 200, 200) should be ~200
        assert 0 <= features.brightness <= 255

    def test_invalid_data_returns_none(self):
        result = analyze_image_bytes(b"not an image")
        assert result is None


class TestAnalyzeImageFile:
    def test_returns_features(self, tmp_path):
        img_path = str(tmp_path / "test.png")
        _make_png_file(img_path)
        features = analyze_image_file(img_path)
        assert features is not None

    def test_nonexistent_file_returns_none(self):
        result = analyze_image_file("/nonexistent/path/image.jpg")
        assert result is None


class TestScoreImage:
    def test_no_keywords_returns_zero(self):
        features = ImageFeatures(exif_description="antique lamp")
        assert score_image(features, []) == 0.0

    def test_no_text_content_returns_zero(self):
        features = ImageFeatures()
        assert score_image(features, ["lamp"]) == 0.0

    def test_full_match(self):
        features = ImageFeatures(
            exif_description="antique victorian lamp",
            exif_keywords=["lamp", "victorian"],
        )
        score = score_image(features, ["lamp", "victorian"])
        assert score == 1.0

    def test_partial_match(self):
        features = ImageFeatures(exif_description="antique lamp")
        score = score_image(features, ["lamp", "table"])
        assert score == 0.5

    def test_no_match_returns_zero(self):
        features = ImageFeatures(exif_description="modern sofa")
        score = score_image(features, ["camera", "leica"])
        assert score == 0.0

    def test_case_insensitive_matching(self):
        features = ImageFeatures(exif_description="Antique Lamp")
        # text_content() lower-cases everything
        score = score_image(features, ["antique"])
        assert score == 1.0
