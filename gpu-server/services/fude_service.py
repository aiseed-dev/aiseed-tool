"""筆ポリゴン GeoJSON インポート・検索サービス。

農水省 open.fude.maff.go.jp からダウンロードした GeoJSON を
パースして DB に保存し、GPS 座標で農地区画を検索する。
"""

import json
import io
import logging
import math
import zipfile
from typing import Optional

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from models.fude_polygon import FudePolygon

logger = logging.getLogger(__name__)

# 土地利用区分ラベル
LAND_TYPE_LABELS = {
    100: "田",
    200: "畑",
}


# ---------- GeoJSON インポート ----------


def _bbox(coords: list) -> tuple[float, float, float, float]:
    """Polygon 座標からバウンディングボックス (min_lat, max_lat, min_lon, max_lon) を返す。"""
    lats = []
    lons = []
    for ring in coords:
        for point in ring:
            lons.append(point[0])
            lats.append(point[1])
    return min(lats), max(lats), min(lons), max(lons)


def _approx_area_m2(coords: list) -> float:
    """緯度経度の Polygon 座標から Shoelace 公式で概算面積 (m²) を計算する。

    赤道付近では正確だが日本の緯度ではそれなりの近似値になる。
    """
    ring = coords[0]  # 外周リングのみ
    if len(ring) < 3:
        return 0.0

    # 緯度の中央値から 1度あたりメートルを計算
    avg_lat = sum(p[1] for p in ring) / len(ring)
    lat_rad = math.radians(avg_lat)
    m_per_deg_lat = 111_320.0
    m_per_deg_lon = 111_320.0 * math.cos(lat_rad)

    # Shoelace formula
    area = 0.0
    n = len(ring)
    for i in range(n):
        j = (i + 1) % n
        xi = ring[i][0] * m_per_deg_lon
        yi = ring[i][1] * m_per_deg_lat
        xj = ring[j][0] * m_per_deg_lon
        yj = ring[j][1] * m_per_deg_lat
        area += xi * yj - xj * yi

    return abs(area) / 2.0


def _parse_geojson(data: dict) -> list[dict]:
    """GeoJSON FeatureCollection をパースして DB 投入用の dict リストを返す。"""
    features = data.get("features", [])
    results = []

    for f in features:
        props = f.get("properties", {})
        geom = f.get("geometry", {})

        if geom.get("type") != "Polygon":
            continue

        coords = geom.get("coordinates", [])
        if not coords:
            continue

        min_lat, max_lat, min_lon, max_lon = _bbox(coords)
        centroid_lat = props.get("point_lat") or (min_lat + max_lat) / 2
        centroid_lon = props.get("point_lng") or (min_lon + max_lon) / 2

        results.append({
            "polygon_uuid": props.get("polygon_uuid", ""),
            "local_government_cd": props.get("local_government_cd", ""),
            "land_type": props.get("land_type", 0),
            "centroid_lat": centroid_lat,
            "centroid_lon": centroid_lon,
            "bbox_min_lat": min_lat,
            "bbox_max_lat": max_lat,
            "bbox_min_lon": min_lon,
            "bbox_max_lon": max_lon,
            "geometry_json": json.dumps(geom),
            "area_m2": round(_approx_area_m2(coords), 1),
            "issue_year": props.get("issue_year", 0),
            "edit_year": props.get("edit_year", 0),
        })

    return results


async def import_geojson(
    db: AsyncSession,
    file_bytes: bytes,
    filename: str,
) -> int:
    """GeoJSON (または ZIP) ファイルをインポートして DB に保存する。

    Returns:
        インポートしたポリゴン数。
    """
    # ZIP ならば中の .json / .geojson を探す
    if filename.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(file_bytes)) as zf:
            geojson_name = None
            for name in zf.namelist():
                if name.endswith((".json", ".geojson")):
                    geojson_name = name
                    break
            if not geojson_name:
                raise ValueError("ZIP 内に GeoJSON ファイルが見つかりません")
            raw = zf.read(geojson_name)
            data = json.loads(raw)
    else:
        data = json.loads(file_bytes)

    records = _parse_geojson(data)
    if not records:
        return 0

    count = 0
    for rec in records:
        # 既存チェック（UUID で重複回避）
        existing = await db.execute(
            select(FudePolygon.id).where(
                FudePolygon.polygon_uuid == rec["polygon_uuid"]
            )
        )
        if existing.scalar_one_or_none() is not None:
            continue

        db.add(FudePolygon(**rec))
        count += 1

    await db.commit()
    logger.info("Fude polygon import: %d new polygons from %s", count, filename)
    return count


# ---------- 点内判定 (Ray Casting) ----------


def _point_in_polygon(lat: float, lon: float, geometry: dict) -> bool:
    """Ray Casting アルゴリズムで点がポリゴン内にあるか判定する。"""
    coords = geometry.get("coordinates", [])
    if not coords:
        return False

    ring = coords[0]  # 外周リング
    n = len(ring)
    inside = False

    j = n - 1
    for i in range(n):
        xi, yi = ring[i][0], ring[i][1]  # lon, lat
        xj, yj = ring[j][0], ring[j][1]

        if ((yi > lat) != (yj > lat)) and \
           (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi):
            inside = not inside
        j = i

    return inside


# ---------- 座標検索 ----------


async def search_by_location(
    db: AsyncSession,
    lat: float,
    lon: float,
    radius_deg: float = 0.005,  # 約 500m
) -> Optional[FudePolygon]:
    """GPS 座標を含む筆ポリゴンを検索する。

    1. バウンディングボックスで候補を絞り込み
    2. Ray Casting で正確な点内判定
    """
    result = await db.execute(
        select(FudePolygon).where(
            and_(
                FudePolygon.bbox_min_lat <= lat + radius_deg,
                FudePolygon.bbox_max_lat >= lat - radius_deg,
                FudePolygon.bbox_min_lon <= lon + radius_deg,
                FudePolygon.bbox_max_lon >= lon - radius_deg,
            )
        )
    )
    candidates = result.scalars().all()

    for poly in candidates:
        geom = json.loads(poly.geometry_json)
        if _point_in_polygon(lat, lon, geom):
            return poly

    return None


async def search_nearby(
    db: AsyncSession,
    lat: float,
    lon: float,
    radius_deg: float = 0.01,  # 約 1km
    limit: int = 20,
) -> list[FudePolygon]:
    """指定座標の周辺にある筆ポリゴンを返す。"""
    result = await db.execute(
        select(FudePolygon).where(
            and_(
                FudePolygon.bbox_min_lat <= lat + radius_deg,
                FudePolygon.bbox_max_lat >= lat - radius_deg,
                FudePolygon.bbox_min_lon <= lon + radius_deg,
                FudePolygon.bbox_max_lon >= lon - radius_deg,
            )
        ).limit(limit)
    )
    return list(result.scalars().all())


async def get_import_stats(db: AsyncSession) -> dict:
    """インポート済みデータの統計を返す。"""
    from sqlalchemy import func

    result = await db.execute(
        select(
            func.count(FudePolygon.id),
            func.count(func.distinct(FudePolygon.local_government_cd)),
        )
    )
    row = result.one()
    return {
        "total_polygons": row[0],
        "municipalities": row[1],
    }
