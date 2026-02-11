"""AMeDAS (気象庁アメダス) data endpoints.

- Sync station master from JMA
- Search stations by name or coordinates
- Fetch observation data for a station + date
- Query stored records
"""

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, desc, func
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.amedas import AmedasStation, AmedasRecord
from services.amedas_service import (
    sync_stations,
    search_stations,
    fetch_and_store_point,
    fetch_day,
    get_latest_time,
    WIND_DIRECTIONS,
)

router = APIRouter(prefix="/amedas", tags=["amedas"])

JST = timezone(timedelta(hours=9))


# ---------- Response Models ----------


class StationResponse(BaseModel):
    station_id: str
    kj_name: str
    kn_name: str
    en_name: str
    lat: float
    lon: float
    alt: float
    type: str
    elems: str

    model_config = {"from_attributes": True}


class ObservationResponse(BaseModel):
    station_id: str
    observed_at: str
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
    station_name: str
    date: str
    count: int
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


def _wind_label(direction: int | None) -> str:
    if direction is None or direction < 1 or direction > 16:
        return ""
    return WIND_DIRECTIONS[direction]


def _record_to_response(r: AmedasRecord) -> ObservationResponse:
    return ObservationResponse(
        station_id=r.station_id,
        observed_at=r.observed_at.isoformat() if r.observed_at else "",
        temp=r.temp,
        humidity=r.humidity,
        pressure=r.pressure,
        wind_speed=r.wind_speed,
        wind_direction=r.wind_direction,
        wind_direction_label=_wind_label(r.wind_direction),
        precipitation_1h=r.precipitation_1h,
        precipitation_24h=r.precipitation_24h,
        sun_1h=r.sun_1h,
        snow=r.snow,
        visibility=r.visibility,
    )


# ---------- Station Endpoints ----------


@router.post("/stations/sync")
async def sync_station_master(db: AsyncSession = Depends(get_db)):
    """Download and sync all AMeDAS station data from JMA."""
    count = await sync_stations(db)
    return {"status": "ok", "stations_synced": count}


@router.get("/stations", response_model=list[StationResponse])
async def list_stations(
    q: str = Query(default="", description="地点名で検索 (漢字/カナ/英語/地点ID)"),
    lat: Optional[float] = Query(default=None, description="緯度（近い順で検索）"),
    lon: Optional[float] = Query(default=None, description="経度（近い順で検索）"),
    limit: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Search AMeDAS stations.

    - Name search: ?q=東京
    - Nearest search: ?lat=35.68&lon=139.77
    """
    # Check if stations are loaded
    count_result = await db.execute(select(func.count(AmedasStation.station_id)))
    if count_result.scalar() == 0:
        # Auto-sync on first access
        await sync_stations(db)

    stations = await search_stations(db, query=q, lat=lat, lon=lon, limit=limit)
    return [StationResponse.model_validate(s) for s in stations]


# ---------- Data Fetch Endpoints ----------


@router.post("/fetch", response_model=FetchResult)
async def fetch_station_data(
    station_id: str = Query(..., description="地点ID (例: 44132)"),
    date: str = Query(
        default="",
        description="日付 YYYY-MM-DD (空なら今日JST)",
    ),
    db: AsyncSession = Depends(get_db),
):
    """Fetch a full day of AMeDAS data for the specified station and date.

    Downloads all 3-hour blocks (00, 03, ..., 21) from JMA.
    """
    if date:
        try:
            target = datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=JST)
        except ValueError:
            raise HTTPException(status_code=400, detail="日付形式が正しくありません (YYYY-MM-DD)")
    else:
        target = datetime.now(JST)

    try:
        count = await fetch_day(db, station_id, target)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"JMAからの取得に失敗: {e}")

    return FetchResult(
        station_id=station_id,
        date=target.strftime("%Y-%m-%d"),
        records_stored=count,
    )


@router.post("/fetch/range", response_model=list[FetchResult])
async def fetch_station_data_range(
    station_id: str = Query(..., description="地点ID"),
    start_date: str = Query(..., description="開始日 YYYY-MM-DD"),
    end_date: str = Query(default="", description="終了日 YYYY-MM-DD (空なら今日)"),
    db: AsyncSession = Depends(get_db),
):
    """Fetch AMeDAS data for a date range."""
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
        raise HTTPException(
            status_code=400,
            detail="JMA APIは約10日分のみ取得可能です",
        )

    results = []
    current = start
    while current <= end:
        try:
            count = await fetch_day(db, station_id, current)
            results.append(FetchResult(
                station_id=station_id,
                date=current.strftime("%Y-%m-%d"),
                records_stored=count,
            ))
        except Exception as e:
            results.append(FetchResult(
                station_id=station_id,
                date=current.strftime("%Y-%m-%d"),
                records_stored=0,
            ))
        current += timedelta(days=1)

    return results


# ---------- Query Endpoints ----------


@router.get("/data/latest", response_model=ObservationResponse)
async def get_latest_observation(
    station_id: str = Query(..., description="地点ID"),
    db: AsyncSession = Depends(get_db),
):
    """Get the most recent stored observation for a station."""
    result = await db.execute(
        select(AmedasRecord)
        .where(AmedasRecord.station_id == station_id)
        .order_by(desc(AmedasRecord.observed_at))
        .limit(1)
    )
    record = result.scalar_one_or_none()
    if record is None:
        raise HTTPException(status_code=404, detail="データがありません。先に /amedas/fetch で取得してください。")
    return _record_to_response(record)


@router.get("/data/history", response_model=list[ObservationResponse])
async def get_observation_history(
    station_id: str = Query(..., description="地点ID"),
    hours: int = Query(default=24, ge=1, le=240),
    limit: int = Query(default=200, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
):
    """Get stored observation history for a station."""
    since = datetime.utcnow() - timedelta(hours=hours)
    result = await db.execute(
        select(AmedasRecord)
        .where(
            AmedasRecord.station_id == station_id,
            AmedasRecord.observed_at >= since,
        )
        .order_by(desc(AmedasRecord.observed_at))
        .limit(limit)
    )
    records = result.scalars().all()
    return [_record_to_response(r) for r in records]


@router.get("/data/summary", response_model=DaySummaryResponse)
async def get_day_summary(
    station_id: str = Query(..., description="地点ID"),
    date: str = Query(default="", description="日付 YYYY-MM-DD (空なら今日)"),
    db: AsyncSession = Depends(get_db),
):
    """Get daily summary for a station."""
    if date:
        try:
            target = datetime.strptime(date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="日付形式が正しくありません")
    else:
        target = datetime.now(JST).replace(tzinfo=None)

    day_start = target.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    result = await db.execute(
        select(
            func.count(AmedasRecord.id),
            func.min(AmedasRecord.temp),
            func.max(AmedasRecord.temp),
            func.avg(AmedasRecord.temp),
            func.avg(AmedasRecord.humidity),
            func.avg(AmedasRecord.wind_speed),
            func.max(AmedasRecord.wind_speed),
            func.sum(AmedasRecord.precipitation_10m),
            func.sum(AmedasRecord.sun_10m),
            func.avg(AmedasRecord.pressure),
        ).where(
            AmedasRecord.station_id == station_id,
            AmedasRecord.observed_at >= day_start,
            AmedasRecord.observed_at < day_end,
        )
    )
    row = result.one()

    # Get station name
    station_result = await db.execute(
        select(AmedasStation).where(AmedasStation.station_id == station_id)
    )
    station = station_result.scalar_one_or_none()
    station_name = station.kj_name if station else station_id

    def _r(val, digits=1):
        return round(val, digits) if val is not None else None

    return DaySummaryResponse(
        station_id=station_id,
        station_name=station_name,
        date=target.strftime("%Y-%m-%d"),
        count=row[0] or 0,
        temp_min=_r(row[1]),
        temp_max=_r(row[2]),
        temp_avg=_r(row[3]),
        humidity_avg=_r(row[4]),
        wind_speed_avg=_r(row[5], 2),
        wind_speed_max=_r(row[6], 2),
        precipitation_total=_r(row[7]),
        sun_total=_r(row[8], 2),
        pressure_avg=_r(row[9]),
    )
