"""Tests for the image_analyzer module."""

import io
import os
from unittest.mock import MagicMock, patch

import pytest

from estate_sale_monitor.image_analyzer import (
    ImageFeatures,
    analyze_image_bytes,
    analyze_image_file,
    score_image,
    _classify_with_vit,
    _get_vit_classifier,
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

    def test_vit_labels_populated_when_classifier_available(self):
        """vit_labels should be populated when the ViT pipeline returns results."""
        mock_results = [
            {"label": "rocking chair", "score": 0.9},
            {"label": "chair", "score": 0.05},
        ]
        mock_classifier = MagicMock(return_value=mock_results)
        import estate_sale_monitor.image_analyzer as ia
        with patch.object(ia, "_vit_classifier", mock_classifier):
            with patch.object(ia, "_TRANSFORMERS_AVAILABLE", True):
                data = _make_jpeg_bytes()
                features = analyze_image_bytes(data)
        assert features is not None
        assert "rocking chair" in features.vit_labels
        assert "chair" in features.vit_labels

    def test_vit_labels_empty_when_classifier_unavailable(self):
        """vit_labels should be empty when transformers is not installed."""
        import estate_sale_monitor.image_analyzer as ia
        with patch.object(ia, "_TRANSFORMERS_AVAILABLE", False):
            with patch.object(ia, "_vit_classifier", None):
                data = _make_jpeg_bytes()
                features = analyze_image_bytes(data)
        assert features is not None
        assert features.vit_labels == []


class TestAnalyzeImageFile:
    def test_returns_features(self, tmp_path):
        img_path = str(tmp_path / "test.png")
        _make_png_file(img_path)
        features = analyze_image_file(img_path)
        assert features is not None

    def test_nonexistent_file_returns_none(self):
        result = analyze_image_file("/nonexistent/path/image.jpg")
        assert result is None


class TestClassifyWithVit:
    def test_returns_lowercase_labels(self):
        """_classify_with_vit should return lowercase label strings."""
        mock_results = [
            {"label": "Rocking Chair", "score": 0.8},
            {"label": "Antique Lamp", "score": 0.1},
        ]
        mock_classifier = MagicMock(return_value=mock_results)
        import estate_sale_monitor.image_analyzer as ia
        with patch.object(ia, "_vit_classifier", mock_classifier):
            with patch.object(ia, "_TRANSFORMERS_AVAILABLE", True):
                img = Image.new("RGB", (10, 10), color=(0, 0, 0))
                labels = _classify_with_vit(img)
        assert labels == ["rocking chair", "antique lamp"]

    def test_returns_empty_when_unavailable(self):
        """_classify_with_vit should return [] when transformers is not installed."""
        import estate_sale_monitor.image_analyzer as ia
        with patch.object(ia, "_TRANSFORMERS_AVAILABLE", False):
            with patch.object(ia, "_vit_classifier", None):
                img = Image.new("RGB", (10, 10))
                labels = _classify_with_vit(img)
        assert labels == []

    def test_returns_empty_on_classifier_error(self):
        """_classify_with_vit should return [] if the classifier raises an exception."""
        mock_classifier = MagicMock(side_effect=RuntimeError("model error"))
        import estate_sale_monitor.image_analyzer as ia
        with patch.object(ia, "_vit_classifier", mock_classifier):
            with patch.object(ia, "_TRANSFORMERS_AVAILABLE", True):
                img = Image.new("RGB", (10, 10))
                labels = _classify_with_vit(img)
        assert labels == []

    def test_respects_top_k(self):
        """_classify_with_vit should pass top_k to the classifier."""
        mock_results = [{"label": "chair", "score": 0.9}]
        mock_classifier = MagicMock(return_value=mock_results)
        import estate_sale_monitor.image_analyzer as ia
        with patch.object(ia, "_vit_classifier", mock_classifier):
            with patch.object(ia, "_TRANSFORMERS_AVAILABLE", True):
                img = Image.new("RGB", (10, 10))
                _classify_with_vit(img, top_k=3)
        mock_classifier.assert_called_once_with(img, top_k=3)


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

    def test_vit_labels_contribute_to_score(self):
        """Keywords matching ViT-predicted labels should raise the score."""
        features = ImageFeatures(vit_labels=["rocking chair", "chair"])
        score = score_image(features, ["chair"])
        assert score == 1.0

    def test_vit_labels_combined_with_exif(self):
        """Score should reflect matches across both EXIF text and ViT labels."""
        features = ImageFeatures(
            exif_description="antique",
            vit_labels=["rocking chair"],
        )
        score = score_image(features, ["antique", "chair"])
        assert score == 1.0
