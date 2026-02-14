"""World clock weather display — ERA5 from S3.

Global weather for any coordinate on Earth.
Data: raw ERA5 (e5.oper.fc.sfc.minmax + accumu) on AWS S3, 0.25° global.
No auth required. Coverage: 1979–present (数日遅れ).
"""

import logging
from datetime import datetime, timedelta

from fastapi import APIRouter, Query
from pydantic import BaseModel

from services.era5_s3 import (
    WORLD_CLOCK_LOCATIONS,
    extract_point_from_s3,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/world-clock", tags=["world-clock"])


# ── Response models ───────────────────────────────────────────────────

class PointWeather(BaseModel):
    lat: float
    lon: float
    date: str
    temp_max: float | None = None       # °C
    temp_min: float | None = None       # °C
    precipitation: float | None = None  # mm
    shortwave_radiation: float | None = None  # MJ/m²


class CityInfo(BaseModel):
    key: str
    name: str
    lat: float
    lon: float
    tz: str


# ── Endpoints ─────────────────────────────────────────────────────────

@router.get("/cities", response_model=list[CityInfo])
async def list_cities():
    """プリセット都市一覧（ショートカット用）。"""
    return [
        CityInfo(key=k, name=v["name"], lat=v["lat"], lon=v["lon"], tz=v["tz"])
        for k, v in WORLD_CLOCK_LOCATIONS.items()
    ]


@router.get("/weather", response_model=PointWeather)
async def get_weather(
    lat: float = Query(..., description="緯度（全世界）", examples=[35.68]),
    lon: float = Query(..., description="経度（全世界）", examples=[139.77]),
    date: str = Query(
        None,
        description="日付 YYYY-MM-DD (省略時は7日前 — S3は数日遅れ)",
    ),
):
    """任意の座標の天気を取得。全世界0.25°解像度。

    旅行先・出張先など、どこでも指定可能。
    例: GET /world-clock/weather?lat=48.86&lon=2.35&date=2025-01-10
    """
    if date is None:
        date = (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%d")

    data = extract_point_from_s3(lat, lon, date)
    return PointWeather(
        lat=lat, lon=lon, date=date,
        temp_max=data.get("temp_max"),
        temp_min=data.get("temp_min"),
        precipitation=data.get("precipitation"),
        shortwave_radiation=data.get("shortwave_radiation"),
    )


@router.get("/weather/range", response_model=list[PointWeather])
async def get_weather_range(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    date_start: str = Query(..., description="開始日 YYYY-MM-DD"),
    date_end: str = Query(..., description="終了日 YYYY-MM-DD"),
):
    """任意の座標の天気を期間で取得。旅行計画用。

    例: GET /world-clock/weather/range?lat=41.90&lon=12.50&date_start=2025-01-01&date_end=2025-01-07
    """
    start = datetime.strptime(date_start, "%Y-%m-%d")
    end = datetime.strptime(date_end, "%Y-%m-%d")

    results: list[PointWeather] = []
    current = start
    while current <= end:
        d = current.strftime("%Y-%m-%d")
        try:
            data = extract_point_from_s3(lat, lon, d)
            results.append(PointWeather(
                lat=lat, lon=lon, date=d,
                temp_max=data.get("temp_max"),
                temp_min=data.get("temp_min"),
                precipitation=data.get("precipitation"),
                shortwave_radiation=data.get("shortwave_radiation"),
            ))
        except Exception as e:
            logger.warning("Range fetch error for %s at (%s,%s): %s", d, lat, lon, e)
            results.append(PointWeather(lat=lat, lon=lon, date=d))
        current += timedelta(days=1)

    return results
