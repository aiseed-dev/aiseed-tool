"""ECMWF 天気予報 API（Open-Meteo 経由、キャッシュなし）。

予報データはリアルタイム取得のみ。ストレージは使わない。
"""

from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel

from services.forecast_service import (
    fetch_ecmwf_forecast,
    parse_forecast,
    summarize_forecast_day,
    weather_code_label,
)

router = APIRouter(prefix="/forecast", tags=["forecast"])


# ---------- レスポンスモデル ----------

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


# ---------- エンドポイント ----------

@router.get("/ecmwf", response_model=ForecastResponse)
async def get_ecmwf_forecast(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    days: int = Query(default=7, ge=1, le=16, description="予報日数"),
    past_days: int = Query(default=0, ge=0, le=2, description="過去日数"),
):
    """ECMWF 予報（土壌温度・水分含む）。"""
    try:
        raw = await fetch_ecmwf_forecast(lat=lat, lon=lon, forecast_days=days, past_days=past_days)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Open-Meteo 取得失敗: {e}")

    records = parse_forecast(raw)
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
    days: int = Query(default=3, ge=1, le=7),
):
    """土壌予報（播種・定植タイミング判断用）。"""
    try:
        raw = await fetch_ecmwf_forecast(lat=lat, lon=lon, forecast_days=days)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Open-Meteo 取得失敗: {e}")
    records = parse_forecast(raw)
    return [HourlyForecast(**r) for r in records]


@router.get("/daily", response_model=list[DailyForecastSummary])
async def get_daily_forecast(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    days: int = Query(default=7, ge=1, le=16),
):
    """日別予報サマリー。"""
    try:
        raw = await fetch_ecmwf_forecast(lat=lat, lon=lon, forecast_days=days)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Open-Meteo 取得失敗: {e}")
    records = parse_forecast(raw)
    dates = sorted(set(r["time"][:10] for r in records))
    return [DailyForecastSummary(**summarize_forecast_day(records, d)) for d in dates]
