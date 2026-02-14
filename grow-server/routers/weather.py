"""Ecowitt GW3000 weather data receiver and query API.

GW3000 sends HTTP POST with application/x-www-form-urlencoded data
at configured intervals (e.g. every 60 seconds).

Ecowitt protocol fields use imperial units:
  - tempf, tempinf: Fahrenheit
  - baromrelin, baromabsin: inHg
  - windspeedmph, windgustmph: mph
  - rainratein, dailyrainin, etc: inches

We convert everything to metric on ingestion.
"""

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.weather import WeatherRecord

logger = logging.getLogger(__name__)

router = APIRouter(tags=["weather"])


# ---------- Unit Conversions ----------

def f_to_c(f: float | None) -> float | None:
    """Fahrenheit to Celsius."""
    if f is None:
        return None
    return round((f - 32) * 5 / 9, 2)


def inhg_to_hpa(inhg: float | None) -> float | None:
    """Inches of mercury to hectopascals."""
    if inhg is None:
        return None
    return round(inhg * 33.8639, 2)


def mph_to_ms(mph: float | None) -> float | None:
    """Miles per hour to meters per second."""
    if mph is None:
        return None
    return round(mph * 0.44704, 2)


def in_to_mm(inches: float | None) -> float | None:
    """Inches to millimeters."""
    if inches is None:
        return None
    return round(inches * 25.4, 2)


def _safe_float(data: dict, key: str) -> float | None:
    """Safely extract a float from form data."""
    val = data.get(key)
    if val is None or val == "":
        return None
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


# ---------- Ecowitt Data Receiver ----------

@router.post("/data/report")
async def receive_ecowitt_data(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Receive weather data from Ecowitt GW3000.

    GW3000 Customized Server settings:
      Protocol: Ecowitt
      Server IP: <this server>
      Path: /data/report
      Port: 8000
    """
    body = await request.body()
    # Parse form-encoded data
    from urllib.parse import parse_qs
    raw = parse_qs(body.decode("utf-8"), keep_blank_values=True)
    # Flatten: parse_qs returns lists, take first value
    data = {k: v[0] if v else "" for k, v in raw.items()}

    logger.info(
        "Weather data received: station=%s, keys=%d",
        data.get("stationtype", "?"),
        len(data),
    )

    # Parse timestamp
    dateutc = data.get("dateutc", "")
    try:
        recorded_at = datetime.strptime(dateutc, "%Y-%m-%d %H:%M:%S").replace(
            tzinfo=timezone.utc
        )
    except (ValueError, TypeError):
        recorded_at = datetime.now(timezone.utc)

    record = WeatherRecord(
        recorded_at=recorded_at,
        station_type=data.get("stationtype", ""),
        passkey=data.get("PASSKEY", ""),

        # Indoor
        temp_indoor_c=f_to_c(_safe_float(data, "tempinf")),
        humidity_indoor=_safe_float(data, "humidityin"),
        pressure_rel_hpa=inhg_to_hpa(_safe_float(data, "baromrelin")),
        pressure_abs_hpa=inhg_to_hpa(_safe_float(data, "baromabsin")),

        # Outdoor
        temp_outdoor_c=f_to_c(_safe_float(data, "tempf")),
        humidity_outdoor=_safe_float(data, "humidity"),

        # Wind
        wind_dir=_safe_float(data, "winddir"),
        wind_speed_ms=mph_to_ms(_safe_float(data, "windspeedmph")),
        wind_gust_ms=mph_to_ms(_safe_float(data, "windgustmph")),
        wind_gust_max_daily_ms=mph_to_ms(_safe_float(data, "maxdailygust")),

        # Solar / UV
        solar_radiation=_safe_float(data, "solarradiation"),
        uv_index=_safe_float(data, "uv"),

        # Rain
        rain_rate_mm=in_to_mm(_safe_float(data, "rainratein")),
        rain_event_mm=in_to_mm(_safe_float(data, "eventrainin")),
        rain_hourly_mm=in_to_mm(_safe_float(data, "hourlyrainin")),
        rain_daily_mm=in_to_mm(_safe_float(data, "dailyrainin")),
        rain_weekly_mm=in_to_mm(_safe_float(data, "weeklyrainin")),
        rain_monthly_mm=in_to_mm(_safe_float(data, "monthlyrainin")),
        rain_yearly_mm=in_to_mm(_safe_float(data, "yearlyrainin")),

        raw_data=json.dumps(data, ensure_ascii=False),
    )

    db.add(record)
    await db.commit()

    return {"status": "ok"}


# ---------- Query API ----------

class WeatherResponse(BaseModel):
    id: int
    recorded_at: str
    temp_indoor_c: float | None = None
    humidity_indoor: float | None = None
    pressure_rel_hpa: float | None = None
    pressure_abs_hpa: float | None = None
    temp_outdoor_c: float | None = None
    humidity_outdoor: float | None = None
    wind_dir: float | None = None
    wind_speed_ms: float | None = None
    wind_gust_ms: float | None = None
    wind_gust_max_daily_ms: float | None = None
    solar_radiation: float | None = None
    uv_index: float | None = None
    rain_rate_mm: float | None = None
    rain_event_mm: float | None = None
    rain_hourly_mm: float | None = None
    rain_daily_mm: float | None = None
    rain_weekly_mm: float | None = None
    rain_monthly_mm: float | None = None
    rain_yearly_mm: float | None = None


class WeatherSummary(BaseModel):
    period: str
    count: int
    temp_outdoor_min: float | None = None
    temp_outdoor_max: float | None = None
    temp_outdoor_avg: float | None = None
    humidity_outdoor_avg: float | None = None
    wind_speed_avg: float | None = None
    wind_gust_max: float | None = None
    solar_radiation_max: float | None = None
    uv_index_max: float | None = None
    rain_daily_max: float | None = None
    pressure_rel_avg: float | None = None


def _record_to_response(r: WeatherRecord) -> WeatherResponse:
    return WeatherResponse(
        id=r.id,
        recorded_at=r.recorded_at.isoformat() if r.recorded_at else "",
        temp_indoor_c=r.temp_indoor_c,
        humidity_indoor=r.humidity_indoor,
        pressure_rel_hpa=r.pressure_rel_hpa,
        pressure_abs_hpa=r.pressure_abs_hpa,
        temp_outdoor_c=r.temp_outdoor_c,
        humidity_outdoor=r.humidity_outdoor,
        wind_dir=r.wind_dir,
        wind_speed_ms=r.wind_speed_ms,
        wind_gust_ms=r.wind_gust_ms,
        wind_gust_max_daily_ms=r.wind_gust_max_daily_ms,
        solar_radiation=r.solar_radiation,
        uv_index=r.uv_index,
        rain_rate_mm=r.rain_rate_mm,
        rain_event_mm=r.rain_event_mm,
        rain_hourly_mm=r.rain_hourly_mm,
        rain_daily_mm=r.rain_daily_mm,
        rain_weekly_mm=r.rain_weekly_mm,
        rain_monthly_mm=r.rain_monthly_mm,
        rain_yearly_mm=r.rain_yearly_mm,
    )


@router.get("/weather/latest", response_model=WeatherResponse)
async def get_latest_weather(db: AsyncSession = Depends(get_db)):
    """Get the most recent weather record."""
    result = await db.execute(
        select(WeatherRecord).order_by(desc(WeatherRecord.recorded_at)).limit(1)
    )
    record = result.scalar_one_or_none()
    if record is None:
        return WeatherResponse(id=0, recorded_at="")
    return _record_to_response(record)


@router.get("/weather/history", response_model=list[WeatherResponse])
async def get_weather_history(
    hours: int = Query(default=24, ge=1, le=168),
    limit: int = Query(default=100, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
):
    """Get weather history for the given number of hours."""
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    result = await db.execute(
        select(WeatherRecord)
        .where(WeatherRecord.recorded_at >= since)
        .order_by(desc(WeatherRecord.recorded_at))
        .limit(limit)
    )
    records = result.scalars().all()
    return [_record_to_response(r) for r in records]


@router.get("/weather/summary", response_model=WeatherSummary)
async def get_weather_summary(
    hours: int = Query(default=24, ge=1, le=720),
    db: AsyncSession = Depends(get_db),
):
    """Get aggregated weather summary for the given period."""
    since = datetime.now(timezone.utc) - timedelta(hours=hours)
    result = await db.execute(
        select(
            func.count(WeatherRecord.id),
            func.min(WeatherRecord.temp_outdoor_c),
            func.max(WeatherRecord.temp_outdoor_c),
            func.avg(WeatherRecord.temp_outdoor_c),
            func.avg(WeatherRecord.humidity_outdoor),
            func.avg(WeatherRecord.wind_speed_ms),
            func.max(WeatherRecord.wind_gust_ms),
            func.max(WeatherRecord.solar_radiation),
            func.max(WeatherRecord.uv_index),
            func.max(WeatherRecord.rain_daily_mm),
            func.avg(WeatherRecord.pressure_rel_hpa),
        ).where(WeatherRecord.recorded_at >= since)
    )
    row = result.one()

    def _round(val, digits=1):
        return round(val, digits) if val is not None else None

    return WeatherSummary(
        period=f"last_{hours}h",
        count=row[0] or 0,
        temp_outdoor_min=_round(row[1]),
        temp_outdoor_max=_round(row[2]),
        temp_outdoor_avg=_round(row[3]),
        humidity_outdoor_avg=_round(row[4]),
        wind_speed_avg=_round(row[5], 2),
        wind_gust_max=_round(row[6], 2),
        solar_radiation_max=_round(row[7]),
        uv_index_max=_round(row[8]),
        rain_daily_max=_round(row[9]),
        pressure_rel_avg=_round(row[10]),
    )
