"""World clock weather display — ERA5 from S3.

Global cities with current weather from raw ERA5 data
(e5.oper.fc.sfc.minmax + accumu on AWS S3, 0.25°).
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

class CityWeather(BaseModel):
    key: str
    name: str
    lat: float
    lon: float
    tz: str
    date: str
    temp_max: float | None = None   # °C
    temp_min: float | None = None   # °C
    precipitation: float | None = None  # mm
    shortwave_radiation: float | None = None  # MJ/m²


class WorldClockResponse(BaseModel):
    date: str
    source: str
    cities: list[CityWeather]


class CityInfo(BaseModel):
    key: str
    name: str
    lat: float
    lon: float
    tz: str


# ── Endpoints ─────────────────────────────────────────────────────────

@router.get("/cities", response_model=list[CityInfo])
async def list_cities():
    """世界時計の対象都市一覧。"""
    return [
        CityInfo(key=k, name=v["name"], lat=v["lat"], lon=v["lon"], tz=v["tz"])
        for k, v in WORLD_CLOCK_LOCATIONS.items()
    ]


@router.get("/weather", response_model=WorldClockResponse)
async def world_weather(
    date: str = Query(
        None,
        description="日付 YYYY-MM-DD (省略時は昨日 — S3は数日遅れ)",
    ),
    cities: str = Query(
        "all",
        description="カンマ区切り都市キー or 'all'",
    ),
):
    """世界主要都市の天気（ERA5 S3）。

    S3のデータは数日〜1週間遅れ。最新は昨日〜数日前。
    例: GET /world-clock/weather?date=2025-01-10&cities=tokyo,roma,new_york
    """
    if date is None:
        # Default to 7 days ago (safe lag for S3 availability)
        date = (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%d")

    if cities == "all":
        targets = WORLD_CLOCK_LOCATIONS
    else:
        keys = [k.strip() for k in cities.split(",") if k.strip()]
        targets = {k: WORLD_CLOCK_LOCATIONS[k] for k in keys if k in WORLD_CLOCK_LOCATIONS}

    results: list[CityWeather] = []
    for key, loc in targets.items():
        try:
            data = extract_point_from_s3(loc["lat"], loc["lon"], date)
            results.append(CityWeather(
                key=key,
                name=loc["name"],
                lat=loc["lat"],
                lon=loc["lon"],
                tz=loc["tz"],
                date=date,
                temp_max=data.get("temp_max"),
                temp_min=data.get("temp_min"),
                precipitation=data.get("precipitation"),
                shortwave_radiation=data.get("shortwave_radiation"),
            ))
        except Exception as e:
            logger.warning("World clock error for %s: %s", key, e)
            results.append(CityWeather(
                key=key, name=loc["name"],
                lat=loc["lat"], lon=loc["lon"], tz=loc["tz"],
                date=date,
            ))

    return WorldClockResponse(
        date=date,
        source="ERA5 S3 (e5.oper.fc.sfc.minmax + accumu)",
        cities=results,
    )
