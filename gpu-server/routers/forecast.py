"""ECMWF forecast endpoints via Open-Meteo API.

Provides hourly forecast with soil temperature/moisture at multiple depths.
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from database import get_db
from models.forecast import ForecastRecord
from services.forecast_service import (
    fetch_ecmwf_forecast,
    parse_forecast,
    summarize_forecast_day,
    weather_code_label,
)

router = APIRouter(prefix="/forecast", tags=["forecast"])


# ---------- Response Models ----------


class HourlyForecast(BaseModel):
    time: str
    temperature_2m: float | None = None
    relative_humidity_2m: float | None = None
    precipitation: float | None = None
    weather_code: int | None = None
    weather_label: str = ""
    pressure_msl: float | None = None
    wind_speed_10m: float | None = None
    wind_direction_10m: float | None = None
    wind_gusts_10m: float | None = None
    sunshine_duration: float | None = None
    surface_temperature: float | None = None
    soil_temperature_0_to_7cm: float | None = None
    soil_temperature_7_to_28cm: float | None = None
    soil_temperature_28_to_100cm: float | None = None
    soil_temperature_100_to_255cm: float | None = None
    soil_moisture_0_to_7cm: float | None = None
    soil_moisture_7_to_28cm: float | None = None
    soil_moisture_28_to_100cm: float | None = None
    soil_moisture_100_to_255cm: float | None = None
    runoff: float | None = None


class DailyForecastSummary(BaseModel):
    date: str
    count: int = 0
    weather_code: int | None = None
    weather_label: str = ""
    temp_min: float | None = None
    temp_max: float | None = None
    temp_avg: float | None = None
    soil_temp_shallow_avg: float | None = None
    soil_moisture_shallow_avg: float | None = None
    precipitation_total: float | None = None
    sunshine_total_min: float | None = None
    wind_speed_avg: float | None = None
    wind_speed_max: float | None = None


class ForecastResponse(BaseModel):
    lat: float
    lon: float
    elevation: float | None = None
    timezone: str = ""
    hourly: list[HourlyForecast]
    daily: list[DailyForecastSummary]


class FetchResult(BaseModel):
    lat: float
    lon: float
    records_stored: int
    forecast_days: int


# ---------- Endpoints ----------


@router.get("/ecmwf", response_model=ForecastResponse)
async def get_ecmwf_forecast(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    days: int = Query(default=7, ge=1, le=16, description="予報日数"),
    past_days: int = Query(default=0, ge=0, le=2, description="過去日数"),
    db: AsyncSession = Depends(get_db),
):
    """Fetch ECMWF forecast from Open-Meteo and return with daily summaries.

    Includes soil temperature/moisture at 4 depths (栽培に有用).
    Data is also stored in DB for historical reference.
    """
    try:
        raw = await fetch_ecmwf_forecast(
            lat=lat, lon=lon, forecast_days=days, past_days=past_days
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Open-Meteo取得失敗: {e}")

    records = parse_forecast(raw)

    # Store in DB
    stored = 0
    for r in records:
        try:
            ft = datetime.fromisoformat(r["time"])
        except (ValueError, TypeError):
            continue

        values = dict(
            lat=round(lat, 2),
            lon=round(lon, 2),
            forecast_time=ft,
            fetched_at=datetime.now(timezone.utc),
            temperature_2m=r.get("temperature_2m"),
            relative_humidity_2m=r.get("relative_humidity_2m"),
            precipitation=r.get("precipitation"),
            weather_code=int(r["weather_code"]) if r.get("weather_code") is not None else None,
            pressure_msl=r.get("pressure_msl"),
            wind_speed_10m=r.get("wind_speed_10m"),
            wind_direction_10m=r.get("wind_direction_10m"),
            wind_gusts_10m=r.get("wind_gusts_10m"),
            sunshine_duration=r.get("sunshine_duration"),
            surface_temperature=r.get("surface_temperature"),
            soil_temp_0_7cm=r.get("soil_temperature_0_to_7cm"),
            soil_temp_7_28cm=r.get("soil_temperature_7_to_28cm"),
            soil_temp_28_100cm=r.get("soil_temperature_28_to_100cm"),
            soil_temp_100_255cm=r.get("soil_temperature_100_to_255cm"),
            soil_moisture_0_7cm=r.get("soil_moisture_0_to_7cm"),
            soil_moisture_7_28cm=r.get("soil_moisture_7_to_28cm"),
            soil_moisture_28_100cm=r.get("soil_moisture_28_to_100cm"),
            soil_moisture_100_255cm=r.get("soil_moisture_100_to_255cm"),
            runoff=r.get("runoff"),
        )

        stmt = sqlite_insert(ForecastRecord).values(**values).on_conflict_do_update(
            index_elements=["lat", "lon", "forecast_time"],
            set_={k: v for k, v in values.items() if k not in ("lat", "lon", "forecast_time")},
        )
        await db.execute(stmt)
        stored += 1

    await db.commit()

    # Build daily summaries
    dates = sorted(set(r["time"][:10] for r in records))
    daily = [summarize_forecast_day(records, d) for d in dates]

    return ForecastResponse(
        lat=raw.get("latitude", lat),
        lon=raw.get("longitude", lon),
        elevation=raw.get("elevation"),
        timezone=raw.get("timezone", ""),
        hourly=[HourlyForecast(**r) for r in records],
        daily=[DailyForecastSummary(**d) for d in daily],
    )


@router.get("/soil", response_model=list[HourlyForecast])
async def get_soil_forecast(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    days: int = Query(default=3, ge=1, le=7, description="予報日数"),
):
    """Get soil-focused forecast (temperature + moisture at all depths).

    Useful for determining sowing/transplanting timing.
    """
    try:
        raw = await fetch_ecmwf_forecast(lat=lat, lon=lon, forecast_days=days)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Open-Meteo取得失敗: {e}")

    records = parse_forecast(raw)
    return [HourlyForecast(**r) for r in records]


@router.get("/daily", response_model=list[DailyForecastSummary])
async def get_daily_forecast(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    days: int = Query(default=7, ge=1, le=16, description="予報日数"),
):
    """Get daily summary forecast (simple overview for planning)."""
    try:
        raw = await fetch_ecmwf_forecast(lat=lat, lon=lon, forecast_days=days)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Open-Meteo取得失敗: {e}")

    records = parse_forecast(raw)
    dates = sorted(set(r["time"][:10] for r in records))
    return [DailyForecastSummary(**summarize_forecast_day(records, d)) for d in dates]
