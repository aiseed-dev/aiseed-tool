"""Fude polygon → AgERA5 grid cell mapping.

Maps farmland centroids (from MAFF 筆ポリゴン data) to 0.1° AgERA5 grid cells.
Only cells containing actual farmland are collected — skip cities, mountains, ocean.

Grid resolution: 0.1° ≈ 9–11 km (matches AgERA5).
At 36°N (central Japan): 0.1° lat ≈ 11.1 km, 0.1° lon ≈ 9.1 km.

Usage:
    # From grow-server's fude database
    centroids = [(35.60, 140.40), (35.61, 140.42), ...]
    cells = snap_to_grid(centroids, resolution=0.1)
    # → {(35.6, 140.4), (35.6, 140.4)}  — deduplicated

    # Or: generate grid cells covering all of Japan's farmland
    cells = japan_farmland_cells()
"""

import logging
import math

import httpx

logger = logging.getLogger(__name__)

GRID_RESOLUTION = 0.1  # degrees (AgERA5 resolution)


def snap_to_grid(
    lat: float, lon: float, resolution: float = GRID_RESOLUTION,
) -> tuple[float, float]:
    """Snap a coordinate to the nearest grid cell center.

    AgERA5 grid: cell centers at 0.05, 0.15, 0.25, ... (i.e. n*0.1 + 0.05)
    But for our storage key (2 decimals), we just round to 0.1.
    """
    grid_lat = round(math.floor(lat / resolution) * resolution + resolution / 2, 2)
    grid_lon = round(math.floor(lon / resolution) * resolution + resolution / 2, 2)
    return (grid_lat, grid_lon)


def centroids_to_grid_cells(
    centroids: list[tuple[float, float]],
    resolution: float = GRID_RESOLUTION,
) -> list[tuple[float, float]]:
    """Convert a list of farmland centroids to unique grid cells.

    Returns deduplicated list of (lat, lon) grid cell centers.
    """
    cells = set()
    for lat, lon in centroids:
        cells.add(snap_to_grid(lat, lon, resolution))
    return sorted(cells)


async def fetch_fude_centroids(
    grow_server_url: str,
    lat_min: float, lat_max: float,
    lon_min: float, lon_max: float,
) -> list[tuple[float, float]]:
    """Fetch fude polygon centroids from grow-server.

    Queries the grow-server's fude database for all polygons
    in the given bounding box, returning their centroids.
    """
    # Use the grow-server's fude/nearby endpoint
    # Scan center + large radius to cover the bbox
    center_lat = (lat_min + lat_max) / 2
    center_lon = (lon_min + lon_max) / 2
    radius = max(lat_max - lat_min, lon_max - lon_min) / 2

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{grow_server_url}/fude/nearby",
            params={
                "lat": center_lat,
                "lon": center_lon,
                "radius_deg": radius,
                "limit": 100000,
            },
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()

    centroids = []
    for polygon in data.get("polygons", []):
        c_lat = polygon.get("centroid_lat")
        c_lon = polygon.get("centroid_lon")
        if c_lat and c_lon:
            centroids.append((c_lat, c_lon))

    logger.info(
        "Fetched %d fude centroids in bbox (%.2f,%.2f)-(%.2f,%.2f)",
        len(centroids), lat_min, lon_min, lat_max, lon_max,
    )
    return centroids


# ── Prefecture bounding boxes (farmland regions) ─────────────────────
# Approximate bounding boxes for each prefecture's agricultural area.
# Used when fude data isn't imported yet — covers known farmland regions.

PREFECTURE_BOUNDS: dict[str, dict] = {
    "hokkaido":  {"lat_min": 41.5, "lat_max": 45.5, "lon_min": 139.5, "lon_max": 145.5,
                  "name": "北海道"},
    "tohoku":    {"lat_min": 37.7, "lat_max": 41.5, "lon_min": 139.0, "lon_max": 141.7,
                  "name": "東北"},
    "kanto":     {"lat_min": 35.0, "lat_max": 37.0, "lon_min": 138.5, "lon_max": 141.0,
                  "name": "関東"},
    "chubu":     {"lat_min": 34.5, "lat_max": 37.8, "lon_min": 136.0, "lon_max": 140.5,
                  "name": "中部"},
    "kinki":     {"lat_min": 33.5, "lat_max": 35.8, "lon_min": 134.0, "lon_max": 136.5,
                  "name": "近畿"},
    "chugoku":   {"lat_min": 33.5, "lat_max": 35.5, "lon_min": 131.0, "lon_max": 134.5,
                  "name": "中国"},
    "shikoku":   {"lat_min": 32.5, "lat_max": 34.5, "lon_min": 132.0, "lon_max": 134.5,
                  "name": "四国"},
    "kyushu":    {"lat_min": 31.0, "lat_max": 34.0, "lon_min": 129.5, "lon_max": 132.0,
                  "name": "九州"},
    "okinawa":   {"lat_min": 24.0, "lat_max": 27.0, "lon_min": 122.5, "lon_max": 128.5,
                  "name": "沖縄"},
}


def generate_grid_for_region(
    lat_min: float, lat_max: float,
    lon_min: float, lon_max: float,
    resolution: float = GRID_RESOLUTION,
) -> list[tuple[float, float]]:
    """Generate all grid cell centers covering a bounding box.

    For use without fude data — covers entire region.
    """
    cells = []
    lat = math.floor(lat_min / resolution) * resolution + resolution / 2
    while lat <= lat_max:
        lon = math.floor(lon_min / resolution) * resolution + resolution / 2
        while lon <= lon_max:
            cells.append((round(lat, 2), round(lon, 2)))
            lon += resolution
        lat += resolution
    return cells
