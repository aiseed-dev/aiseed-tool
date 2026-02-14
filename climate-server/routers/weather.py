"""Ecowitt GW3000 気象データ受信・照会API（Parquet ストレージ）。

GW3000 は HTTP POST（application/x-www-form-urlencoded）で送信。
imperial 単位をメトリックに変換して Parquet に保存。
"""

import json
import logging
from datetime import datetime, timezone

import pandas as pd
from fastapi import APIRouter, Query, Request
from pydantic import BaseModel
from pathlib import Path

from config import settings
from storage.parquet_store import append_records, read_recent, read_latest

logger = logging.getLogger(__name__)

router = APIRouter(tags=["weather"])

def _ecowitt_dir() -> Path:
    return Path(settings.data_dir) / "ecowitt"

TIME_COL = "recorded_at"


# ---------- 単位変換 ----------

def f_to_c(f: float | None) -> float | None:
    if f is None: return None
    return round((f - 32) * 5 / 9, 2)

def inhg_to_hpa(v: float | None) -> float | None:
    if v is None: return None
    return round(v * 33.8639, 2)

def mph_to_ms(v: float | None) -> float | None:
    if v is None: return None
    return round(v * 0.44704, 2)

def in_to_mm(v: float | None) -> float | None:
    if v is None: return None
    return round(v * 25.4, 2)

def _safe_float(data: dict, key: str) -> float | None:
    val = data.get(key)
    if val is None or val == "":
        return None
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


# ---------- データ受信 ----------

@router.post("/data/report")
async def receive_ecowitt_data(request: Request):
    """Ecowitt GW3000 からのデータ受信。

    GW3000 設定: Protocol=Ecowitt, Path=/data/report, Port=8100
    """
    body = await request.body()
    from urllib.parse import parse_qs
    raw = parse_qs(body.decode("utf-8"), keep_blank_values=True)
    data = {k: v[0] if v else "" for k, v in raw.items()}

    logger.info("Weather data received: station=%s, keys=%d",
                data.get("stationtype", "?"), len(data))

    dateutc = data.get("dateutc", "")
    try:
        recorded_at = datetime.strptime(dateutc, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        recorded_at = datetime.now(timezone.utc)

    record = {
        "recorded_at": recorded_at.isoformat(),
        "station_type": data.get("stationtype", ""),
        # 屋内
        "temp_indoor_c": f_to_c(_safe_float(data, "tempinf")),
        "humidity_indoor": _safe_float(data, "humidityin"),
        "pressure_rel_hpa": inhg_to_hpa(_safe_float(data, "baromrelin")),
        "pressure_abs_hpa": inhg_to_hpa(_safe_float(data, "baromabsin")),
        # 屋外
        "temp_outdoor_c": f_to_c(_safe_float(data, "tempf")),
        "humidity_outdoor": _safe_float(data, "humidity"),
        # 風
        "wind_dir": _safe_float(data, "winddir"),
        "wind_speed_ms": mph_to_ms(_safe_float(data, "windspeedmph")),
        "wind_gust_ms": mph_to_ms(_safe_float(data, "windgustmph")),
        "wind_gust_max_daily_ms": mph_to_ms(_safe_float(data, "maxdailygust")),
        # 日射 / UV
        "solar_radiation": _safe_float(data, "solarradiation"),
        "uv_index": _safe_float(data, "uv"),
        # 降水量
        "rain_rate_mm": in_to_mm(_safe_float(data, "rainratein")),
        "rain_event_mm": in_to_mm(_safe_float(data, "eventrainin")),
        "rain_hourly_mm": in_to_mm(_safe_float(data, "hourlyrainin")),
        "rain_daily_mm": in_to_mm(_safe_float(data, "dailyrainin")),
        "rain_weekly_mm": in_to_mm(_safe_float(data, "weeklyrainin")),
        "rain_monthly_mm": in_to_mm(_safe_float(data, "monthlyrainin")),
        "rain_yearly_mm": in_to_mm(_safe_float(data, "yearlyrainin")),
    }

    count = append_records(_ecowitt_dir(), [record])
    return {"status": "ok", "stored": count}


# ---------- 照会 ----------

class WeatherResponse(BaseModel):
    recorded_at: str = ""
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
    count: int = 0
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


def _row_to_response(row: dict) -> WeatherResponse:
    ts = row.get("recorded_at", "")
    if hasattr(ts, "isoformat"):
        ts = ts.isoformat()
    return WeatherResponse(
        recorded_at=str(ts),
        temp_indoor_c=row.get("temp_indoor_c"),
        humidity_indoor=row.get("humidity_indoor"),
        pressure_rel_hpa=row.get("pressure_rel_hpa"),
        pressure_abs_hpa=row.get("pressure_abs_hpa"),
        temp_outdoor_c=row.get("temp_outdoor_c"),
        humidity_outdoor=row.get("humidity_outdoor"),
        wind_dir=row.get("wind_dir"),
        wind_speed_ms=row.get("wind_speed_ms"),
        wind_gust_ms=row.get("wind_gust_ms"),
        wind_gust_max_daily_ms=row.get("wind_gust_max_daily_ms"),
        solar_radiation=row.get("solar_radiation"),
        uv_index=row.get("uv_index"),
        rain_rate_mm=row.get("rain_rate_mm"),
        rain_event_mm=row.get("rain_event_mm"),
        rain_hourly_mm=row.get("rain_hourly_mm"),
        rain_daily_mm=row.get("rain_daily_mm"),
        rain_weekly_mm=row.get("rain_weekly_mm"),
        rain_monthly_mm=row.get("rain_monthly_mm"),
        rain_yearly_mm=row.get("rain_yearly_mm"),
    )


@router.get("/weather/latest", response_model=WeatherResponse)
async def get_latest_weather():
    """最新の気象データ。"""
    row = read_latest(_ecowitt_dir(), TIME_COL)
    if row is None:
        return WeatherResponse()
    return _row_to_response(row)


@router.get("/weather/history", response_model=list[WeatherResponse])
async def get_weather_history(
    hours: int = Query(default=24, ge=1, le=168),
    limit: int = Query(default=100, ge=1, le=1000),
):
    """指定時間内の気象データ履歴。"""
    df = read_recent(_ecowitt_dir(), TIME_COL, hours=hours, limit=limit)
    if df.empty:
        return []
    return [_row_to_response(row) for row in df.to_dict("records")]


@router.get("/weather/summary", response_model=WeatherSummary)
async def get_weather_summary(
    hours: int = Query(default=24, ge=1, le=720),
):
    """指定期間の気象サマリー。"""
    df = read_recent(_ecowitt_dir(), TIME_COL, hours=hours, limit=100000)
    if df.empty:
        return WeatherSummary(period=f"last_{hours}h", count=0)

    def _r(val, d=1):
        return round(float(val), d) if pd.notna(val) else None

    return WeatherSummary(
        period=f"last_{hours}h",
        count=len(df),
        temp_outdoor_min=_r(df["temp_outdoor_c"].min()),
        temp_outdoor_max=_r(df["temp_outdoor_c"].max()),
        temp_outdoor_avg=_r(df["temp_outdoor_c"].mean()),
        humidity_outdoor_avg=_r(df["humidity_outdoor"].mean()),
        wind_speed_avg=_r(df["wind_speed_ms"].mean(), 2),
        wind_gust_max=_r(df["wind_gust_ms"].max(), 2),
        solar_radiation_max=_r(df["solar_radiation"].max()),
        uv_index_max=_r(df["uv_index"].max()),
        rain_daily_max=_r(df["rain_daily_mm"].max()),
        pressure_rel_avg=_r(df["pressure_rel_hpa"].mean()),
    )
