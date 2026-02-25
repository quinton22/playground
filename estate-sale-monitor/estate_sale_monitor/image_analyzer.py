"""Image analysis: metadata inspection and visual characterization."""

from __future__ import annotations

import io
import logging
import math
import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

try:
    from PIL import Image, ExifTags, ImageStat
    _PIL_AVAILABLE = True
except ImportError:  # pragma: no cover
    _PIL_AVAILABLE = False
    logger.warning("Pillow not installed; image analysis will be limited.")


@dataclass
class ImageFeatures:
    """Visual and metadata features extracted from an image."""

    # Metadata
    exif_description: str = ""
    exif_keywords: List[str] = field(default_factory=list)
    exif_camera_model: str = ""
    exif_date: str = ""

    # Visual characteristics
    width: int = 0
    height: int = 0
    dominant_colors: List[Tuple[int, int, int]] = field(default_factory=list)
    brightness: float = 0.0   # 0–255
    contrast: float = 0.0     # standard deviation of luminance
    edge_density: float = 0.0  # fraction of high-gradient pixels (0–1)

    def text_content(self) -> str:
        """Return all text-like features concatenated for keyword matching."""
        parts = [self.exif_description] + self.exif_keywords + [self.exif_camera_model]
        return " ".join(parts).lower()


def _extract_exif(image: "Image.Image") -> Dict:
    """Return a dict of decoded EXIF tags from a PIL image."""
    exif_data: Dict = {}
    try:
        raw = image._getexif()  # type: ignore[attr-defined]
        if raw is None:
            return exif_data
        for tag_id, value in raw.items():
            tag = ExifTags.TAGS.get(tag_id, str(tag_id))
            exif_data[tag] = value
    except (AttributeError, Exception) as exc:
        logger.debug("EXIF extraction failed: %s", exc)
    return exif_data


def _dominant_colors(
    image: "Image.Image", n: int = 5, sample_size: int = 100
) -> List[Tuple[int, int, int]]:
    """Return up to *n* dominant colors using a simple quantization approach."""
    img = image.convert("RGB").resize(
        (sample_size, sample_size), Image.Resampling.LANCZOS
    )
    quantized = img.quantize(colors=n, method=Image.Quantize.FASTOCTREE)
    palette_rgb = quantized.convert("RGB")
    # Collect color from each palette index
    colors: List[Tuple[int, int, int]] = []
    seen = set()
    pixel_data = (
        palette_rgb.get_flattened_data()
        if hasattr(palette_rgb, "get_flattened_data")
        else list(palette_rgb.getdata())
    )
    for px in pixel_data:
        if px not in seen:
            seen.add(px)
            colors.append(px)
        if len(colors) >= n:
            break
    return colors


def _edge_density(image: "Image.Image", threshold: int = 30) -> float:
    """Estimate edge density as the fraction of pixels with high gradient."""
    gray = image.convert("L").resize((64, 64), Image.Resampling.LANCZOS)
    pixel_data = (
        gray.get_flattened_data()
        if hasattr(gray, "get_flattened_data")
        else list(gray.getdata())
    )
    pixels = list(pixel_data)
    width, height = gray.size
    edge_count = 0
    total = 0
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            idx = y * width + x
            gx = abs(int(pixels[idx + 1]) - int(pixels[idx - 1]))
            gy = abs(int(pixels[idx + width]) - int(pixels[idx - width]))
            gradient = math.sqrt(gx * gx + gy * gy)
            if gradient > threshold:
                edge_count += 1
            total += 1
    return edge_count / total if total > 0 else 0.0


def analyze_image_file(path: str) -> Optional[ImageFeatures]:
    """Analyze an image file and return its :class:`ImageFeatures`.

    Args:
        path: Filesystem path to the image.

    Returns:
        :class:`ImageFeatures` or ``None`` if the file cannot be read.
    """
    if not _PIL_AVAILABLE:
        return None
    if not os.path.isfile(path):
        logger.warning("Image file not found: %s", path)
        return None
    try:
        with Image.open(path) as img:
            return _analyze(img)
    except Exception as exc:  # pylint: disable=broad-except
        logger.warning("Failed to analyze %s: %s", path, exc)
        return None


def analyze_image_bytes(data: bytes) -> Optional[ImageFeatures]:
    """Analyze raw image bytes and return its :class:`ImageFeatures`.

    Args:
        data: Raw image bytes (JPEG, PNG, etc.).

    Returns:
        :class:`ImageFeatures` or ``None`` on failure.
    """
    if not _PIL_AVAILABLE:
        return None
    try:
        with Image.open(io.BytesIO(data)) as img:
            return _analyze(img)
    except Exception as exc:  # pylint: disable=broad-except
        logger.warning("Failed to analyze image bytes: %s", exc)
        return None


def _analyze(img: "Image.Image") -> ImageFeatures:
    """Core analysis logic shared by file and bytes entry points."""
    features = ImageFeatures(width=img.width, height=img.height)

    # --- EXIF metadata ---
    exif = _extract_exif(img)
    features.exif_description = str(exif.get("ImageDescription", ""))
    features.exif_camera_model = str(exif.get("Model", ""))
    features.exif_date = str(exif.get("DateTimeOriginal", exif.get("DateTime", "")))
    # XPKeywords is a Windows-specific EXIF field that stores comma-separated keywords
    raw_kw = exif.get("XPKeywords", b"")
    if isinstance(raw_kw, bytes):
        try:
            raw_kw = raw_kw.decode("utf-16-le", errors="ignore")
        except Exception:
            raw_kw = ""
    features.exif_keywords = [k.strip() for k in str(raw_kw).split(";") if k.strip()]

    # --- Visual characteristics ---
    try:
        features.dominant_colors = _dominant_colors(img)
    except Exception as exc:
        logger.debug("Dominant color extraction failed: %s", exc)

    try:
        stat = ImageStat.Stat(img.convert("L"))
        features.brightness = stat.mean[0]
        features.contrast = stat.stddev[0]
    except Exception as exc:
        logger.debug("Brightness/contrast extraction failed: %s", exc)

    try:
        features.edge_density = _edge_density(img)
    except Exception as exc:
        logger.debug("Edge density extraction failed: %s", exc)

    return features


def score_image(features: ImageFeatures, keywords: List[str]) -> float:
    """Compute a match score (0–1) between image features and a list of keywords.

    The score is based on how many of the *keywords* appear in the image's
    textual metadata.  If the image has no metadata, the score is 0.

    Args:
        features: :class:`ImageFeatures` extracted from an image.
        keywords: List of lowercase search keywords.

    Returns:
        Score between 0.0 and 1.0.
    """
    if not keywords:
        return 0.0
    text = features.text_content()
    if not text.strip():
        return 0.0
    matched = sum(1 for kw in keywords if kw in text)
    return matched / len(keywords)
