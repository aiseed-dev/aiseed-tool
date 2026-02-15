"""AMeDAS（気象庁アメダス）データ取得・照会 API（Parquet ストレージ）。

地点マスターは JSON、観測データは Parquet で保存。
"""

import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

import pandas as pd
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel

from config import settings
from services.amedas_service import (
    sync_stations,
    search_stations_from_file,
    fetch_day_to_parquet,
    WIND_DIRECTIONS,
)
from storage.parquet_store import read_recent, read_range

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/amedas", tags=["amedas"])

JST = timezone(timedelta(hours=9))
TIME_COL = "observed_at"


def _station_dir(station_id: str) -> Path:
    return Path(settings.data_dir) / "amedas" / station_id


def _stations_file() -> Path:
    return Path(settings.data_dir) / "amedas" / "stations.json"


# ---------- レスポンスモデル ----------

class StationResponse(BaseModel):
    station_id: str
    kj_name: str = ""
    kn_name: str = ""
    en_name: str = ""
    lat: float = 0.0
    lon: float = 0.0
    alt: float = 0.0
    type: str = ""
    elems: str = ""


class ObservationResponse(BaseModel):
    station_id: str = ""
    observed_at: str = ""
    temp: float | None = None
    humidity: float | None = None
    pressure: float | None = None
    wind_speed: float | None = None
    wind_direction: int | None = None
    wind_direction_label: str = ""
    precipitation_1h: float | None = None
    precipitation_24h: float | None = None
    sun_1h: float | None = None
    snow: float | None = None
    visibility: float | None = None


class DaySummaryResponse(BaseModel):
    station_id: str
    station_name: str = ""
    date: str = ""
    count: int = 0
    temp_min: float | None = None
    temp_max: float | None = None
    temp_avg: float | None = None
    humidity_avg: float | None = None
    wind_speed_avg: float | None = None
    wind_speed_max: float | None = None
    precipitation_total: float | None = None
    sun_total: float | None = None
    pressure_avg: float | None = None


class FetchResult(BaseModel):
    station_id: str
    date: str
    records_stored: int


def _wind_label(direction) -> str:
    if direction is None or pd.isna(direction):
        return ""
    d = int(direction)
    if d < 1 or d > 16:
        return ""
    return WIND_DIRECTIONS[d]


def _row_to_obs(row: dict) -> ObservationResponse:
    ts = row.get("observed_at", "")
    if hasattr(ts, "isoformat"):
        ts = ts.isoformat()
    return ObservationResponse(
        station_id=str(row.get("station_id", "")),
        observed_at=str(ts),
        temp=row.get("temp"),
        humidity=row.get("humidity"),
        pressure=row.get("pressure"),
        wind_speed=row.get("wind_speed"),
        wind_direction=int(row["wind_direction"]) if pd.notna(row.get("wind_direction")) else None,
        wind_direction_label=_wind_label(row.get("wind_direction")),
        precipitation_1h=row.get("precipitation_1h"),
        precipitation_24h=row.get("precipitation_24h"),
        sun_1h=row.get("sun_1h"),
        snow=row.get("snow"),
        visibility=row.get("visibility"),
    )


def _get_station_name(station_id: str) -> str:
    path = _stations_file()
    if not path.exists():
        return station_id
    with open(path) as f:
        stations = json.load(f)
    info = stations.get(station_id, {})
    return info.get("kj_name", station_id)


# ---------- 地点エンドポイント ----------

@router.post("/stations/sync")
async def sync_station_master():
    """JMA から AMeDAS 地点マスターをダウンロード。"""
    count = await sync_stations(_stations_file())
    return {"status": "ok", "stations_synced": count}


@router.get("/stations", response_model=list[StationResponse])
async def list_stations(
    q: str = Query(default="", description="地点名で検索"),
    lat: Optional[float] = Query(default=None),
    lon: Optional[float] = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
):
    """AMeDAS 地点検索。"""
    path = _stations_file()
    if not path.exists():
        await sync_stations(path)
    stations = search_stations_from_file(path, query=q, lat=lat, lon=lon, limit=limit)
    return [StationResponse(**s) for s in stations]


# ---------- データ取得 ----------

@router.post("/fetch", response_model=FetchResult)
async def fetch_station_data(
    station_id: str = Query(..., description="地点ID (例: 44132)"),
    date: str = Query(default="", description="日付 YYYY-MM-DD"),
):
    """指定日の AMeDAS データを JMA から取得して Parquet に保存。"""
    if date:
        try:
            target = datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=JST)
        except ValueError:
            raise HTTPException(status_code=400, detail="日付形式が正しくありません")
    else:
        target = datetime.now(JST)

    try:
        count = await fetch_day_to_parquet(_station_dir(station_id), station_id, target)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"JMA からの取得に失敗: {e}")

    return FetchResult(station_id=station_id, date=target.strftime("%Y-%m-%d"), records_stored=count)


@router.post("/fetch/range", response_model=list[FetchResult])
async def fetch_station_data_range(
    station_id: str = Query(..., description="地点ID"),
    start_date: str = Query(..., description="開始日 YYYY-MM-DD"),
    end_date: str = Query(default="", description="終了日 YYYY-MM-DD"),
):
    """期間指定で AMeDAS データ取得。"""
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d").replace(tzinfo=JST)
    except ValueError:
        raise HTTPException(status_code=400, detail="開始日の形式が正しくありません")

    if end_date:
        try:
            end = datetime.strptime(end_date, "%Y-%m-%d").replace(tzinfo=JST)
        except ValueError:
            raise HTTPException(status_code=400, detail="終了日の形式が正しくありません")
    else:
        end = datetime.now(JST)

    if (end - start).days > 10:
        raise HTTPException(status_code=400, detail="JMA API は約10日分のみ取得可能です")

    results = []
    current = start
    while current <= end:
        try:
            count = await fetch_day_to_parquet(_station_dir(station_id), station_id, current)
            results.append(FetchResult(station_id=station_id, date=current.strftime("%Y-%m-%d"), records_stored=count))
        except Exception:
            results.append(FetchResult(station_id=station_id, date=current.strftime("%Y-%m-%d"), records_stored=0))
        current += timedelta(days=1)

    return results


@router.post("/fetch/refresh")
async def refresh_registered_stations():
    """登録地点の最新データを手動取得。"""
    from services.amedas_scheduler import fetch_all_stations
    if not settings.amedas_stations:
        raise HTTPException(status_code=400, detail="CLIMATE_AMEDAS_STATIONS が未設定です")
    station_ids = [s.strip() for s in settings.amedas_stations.split(",") if s.strip()][:3]
    results = await fetch_all_stations(station_ids)
    return {"status": "ok", "results": results}


# ---------- 照会 ----------

@router.get("/data/latest", response_model=ObservationResponse)
async def get_latest_observation(station_id: str = Query(...)):
    """最新の観測データ。"""
    from storage.parquet_store import read_latest
    row = read_latest(_station_dir(station_id), TIME_COL)
    if row is None:
        raise HTTPException(status_code=404, detail="データがありません")
    row["station_id"] = station_id
    return _row_to_obs(row)


@router.get("/data/history", response_model=list[ObservationResponse])
async def get_observation_history(
    station_id: str = Query(...),
    hours: int = Query(default=24, ge=1, le=240),
    limit: int = Query(default=200, ge=1, le=1000),
):
    """観測データ履歴。"""
    df = read_recent(_station_dir(station_id), TIME_COL, hours=hours, limit=limit)
    if df.empty:
        return []
    df["station_id"] = station_id
    return [_row_to_obs(row) for row in df.to_dict("records")]


@router.get("/data/summary", response_model=DaySummaryResponse)
async def get_day_summary(
    station_id: str = Query(...),
    date: str = Query(default=""),
):
    """日別サマリー。"""
    if date:
        try:
            target = datetime.strptime(date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="日付形式が正しくありません")
    else:
        target = datetime.now(JST).replace(tzinfo=None)

    day_start = target.replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=timezone.utc)
    day_end = day_start + timedelta(days=1)

    df = read_range(_station_dir(station_id), TIME_COL, day_start, day_end)
    if df.empty:
        return DaySummaryResponse(station_id=station_id, station_name=_get_station_name(station_id), date=target.strftime("%Y-%m-%d"))

    def _r(val, d=1):
        return round(float(val), d) if pd.notna(val) else None

    return DaySummaryResponse(
        station_id=station_id,
        station_name=_get_station_name(station_id),
        date=target.strftime("%Y-%m-%d"),
        count=len(df),
        temp_min=_r(df["temp"].min()),
        temp_max=_r(df["temp"].max()),
        temp_avg=_r(df["temp"].mean()),
        humidity_avg=_r(df["humidity"].mean()),
        wind_speed_avg=_r(df["wind_speed"].mean(), 2),
        wind_speed_max=_r(df["wind_speed"].max(), 2),
        precipitation_total=_r(df["precipitation_10m"].sum()),
        sun_total=_r(df["sun_10m"].sum(), 2),
        pressure_avg=_r(df["pressure"].mean()),
    )
