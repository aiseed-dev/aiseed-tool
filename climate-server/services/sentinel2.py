"""Sentinel-2 vegetation indices via Element 84 Earth Search (AWS).

No authentication required — public STAC API + public COG files.
STAC endpoint: https://earth-search.aws.element84.com/v1
Collection: sentinel-2-l2a

Indices calculated:
    NDVI  — 植物活力 (B08, B04 = 10 m)
    NDRE  — クロロフィル/窒素 (B07, B05 = 20 m)
    CIre  — クロロフィル指数 (B07, B05 = 20 m)
    NDMI  — 水分ストレス (B08, B11 = 10/20 m)
    BSI   — 裸地指数 (B11, B04, B08, B02 = 10/20 m)
    LAI   — 葉面積指数 (empirical from NDVI)

Resolution: 10–20 m, revisit 2–5 days.
Cloud masking via SCL band (keep values 4, 5, 6).
"""

import logging
from datetime import datetime

import numpy as np

logger = logging.getLogger(__name__)

# ── Band mapping (Earth Search v1 asset keys) ────────────────────────

STAC_ENDPOINT = "https://earth-search.aws.element84.com/v1"
COLLECTION = "sentinel-2-l2a"

# Earth Search v1 uses descriptive asset names
BAND_ASSETS = {
    "B02": "blue",       # 490 nm, 10 m
    "B03": "green",      # 560 nm, 10 m
    "B04": "red",        # 665 nm, 10 m
    "B05": "rededge1",   # 705 nm, 20 m
    "B06": "rededge2",   # 740 nm, 20 m
    "B07": "rededge3",   # 783 nm, 20 m
    "B08": "nir",        # 842 nm, 10 m
    "B8A": "nir08",      # 865 nm, 20 m
    "B11": "swir16",     # 1610 nm, 20 m
    "B12": "swir22",     # 2190 nm, 20 m
    "SCL": "scl",        # Scene Classification, 20 m
}

# SCL values to keep (clear sky)
SCL_CLEAR = {4, 5, 6}  # vegetation, not-vegetated, water


# ── Index formulas ───────────────────────────────────────────────────

def _safe_norm_diff(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """(a - b) / (a + b) with zero-division protection."""
    with np.errstate(divide="ignore", invalid="ignore"):
        denom = a + b
        result = np.where(np.abs(denom) > 1e-10, (a - b) / denom, 0.0)
    return result.astype(np.float32)


def ndvi(b04: np.ndarray, b08: np.ndarray) -> np.ndarray:
    """NDVI = (NIR - Red) / (NIR + Red).  Range: -1 to 1."""
    return _safe_norm_diff(b08, b04)


def ndre(b05: np.ndarray, b07: np.ndarray) -> np.ndarray:
    """NDRE = (RE3 - RE1) / (RE3 + RE1).  Range: -1 to 1."""
    return _safe_norm_diff(b07, b05)


def cire(b05: np.ndarray, b07: np.ndarray) -> np.ndarray:
    """Chlorophyll Index Red Edge = (B07 / B05) - 1.  Range: 0–20."""
    with np.errstate(divide="ignore", invalid="ignore"):
        result = np.where(np.abs(b05) > 1e-10, b07 / b05 - 1.0, 0.0)
    return result.astype(np.float32)


def ndmi(b08: np.ndarray, b11: np.ndarray) -> np.ndarray:
    """NDMI = (NIR - SWIR1) / (NIR + SWIR1).  Range: -1 to 1."""
    return _safe_norm_diff(b08, b11)


def bsi(
    b02: np.ndarray, b04: np.ndarray,
    b08: np.ndarray, b11: np.ndarray,
) -> np.ndarray:
    """Bare Soil Index.  Range: -1 to 1."""
    num = (b11 + b04) - (b08 + b02)
    den = (b11 + b04) + (b08 + b02)
    return _safe_norm_diff(num + b08 + b02, den + b08 + b02 - num - b08 - b02)


def lai_empirical(ndvi_arr: np.ndarray) -> np.ndarray:
    """Empirical LAI ≈ 0.57 * exp(2.33 * NDVI).  Rough estimate."""
    with np.errstate(over="ignore"):
        result = 0.57 * np.exp(2.33 * np.clip(ndvi_arr, 0, 1))
    return np.clip(result, 0, 10).astype(np.float32)


# ── Point extraction (mean over small bbox) ──────────────────────────

INDEX_DESCRIPTIONS = {
    "ndvi": "植物活力 — Normalized Difference Vegetation Index",
    "ndre": "クロロフィル/窒素 — Normalized Difference Red Edge",
    "cire": "クロロフィル含量 — Chlorophyll Index Red Edge",
    "ndmi": "水分ストレス — Normalized Difference Moisture Index",
    "bsi":  "裸地指数 — Bare Soil Index",
    "lai":  "葉面積指数 — Leaf Area Index (empirical)",
}

# Jones 5 principles × Sentinel-2 correspondence
JONES_MAPPING = {
    "年間緑被":     ["ndvi", "bsi"],
    "光合成速度":   ["ndre", "cire"],
    "光合成容量":   ["lai"],
    "多様性の効果": ["ndmi"],
    "化学資材の影響": ["ndre"],  # nitrogen status over time
}
