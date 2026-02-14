"""ERA5 climate data endpoints.

Provides historical monthly climate data for:
  - 栽培適性分析 (soil temp, moisture, precipitation)
  - 世界時計 weather context (temperature, conditions per city)
  - 長期トレンド分析 (30+ years of monthly data)
"""

import httpx
from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, and_, func, distinct
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from database import get_db
from models.era5 import ERA5ClimateRecord
from services.era5_service import (
    fetch_era5_open_meteo,
    fetch_era5_aws_metadata,
    fetch_era5_aws_point,
    fetch_era5_land_cds,
    get_location,
    WORLD_LOCATIONS,
)

router = APIRouter(prefix="/era5", tags=["era5"])


# ── Response models ───────────────────────────────────────────────────


class ERA5Monthly(BaseModel):
    lat: float
    lon: float
    year: int
    month: int
    source: str
    dataset: str
    resolution: float
    temp_mean: float | None = None
    temp_min: float | None = None
    temp_max: float | None = None
    precipitation_total: float | None = None
    rain_total: float | None = None
    snowfall_total: float | None = None
    wind_speed_mean: float | None = None
    wind_speed_max: float | None = None
    wind_gusts_max: float | None = None
    humidity_mean: float | None = None
    pressure_mean: float | None = None
    sunshine_hours: float | None = None
    solar_radiation: float | None = None
    et0_total: float | None = None
    soil_temp_0_7cm: float | None = None
    soil_temp_7_28cm: float | None = None
    soil_temp_28_100cm: float | None = None
    soil_temp_100_255cm: float | None = None
    soil_moisture_0_7cm: float | None = None
    soil_moisture_7_28cm: float | None = None
    soil_moisture_28_100cm: float | None = None
    soil_moisture_100_255cm: float | None = None


class LocationInfo(BaseModel):
    key: str
    name: str
    lat: float
    lon: float
    tz: str


class CollectResult(BaseModel):
    location: str
    year: int
    month: int
    source: str
    status: str  # ok / skipped / error
    message: str = ""


class CollectSummary(BaseModel):
    total: int
    ok: int
    skipped: int
    errors: int
    results: list[CollectResult]


# ── Helpers ───────────────────────────────────────────────────────────


async def _upsert(db: AsyncSession, data: dict) -> None:
    stmt = (
        sqlite_insert(ERA5ClimateRecord)
        .values(**data)
        .on_conflict_do_update(
            index_elements=["lat", "lon", "year", "month", "source"],
            set_={
                k: v for k, v in data.items()
                if k not in ("lat", "lon", "year", "month", "source")
            },
        )
    )
    await db.execute(stmt)
    await db.commit()


def _record_to_response(r: ERA5ClimateRecord) -> ERA5Monthly:
    return ERA5Monthly(
        lat=r.lat, lon=r.lon, year=r.year, month=r.month,
        source=r.source, dataset=r.dataset, resolution=r.resolution,
        temp_mean=r.temp_mean, temp_min=r.temp_min, temp_max=r.temp_max,
        precipitation_total=r.precipitation_total,
        rain_total=r.rain_total, snowfall_total=r.snowfall_total,
        wind_speed_mean=r.wind_speed_mean, wind_speed_max=r.wind_speed_max,
        wind_gusts_max=r.wind_gusts_max,
        humidity_mean=r.humidity_mean, pressure_mean=r.pressure_mean,
        sunshine_hours=r.sunshine_hours, solar_radiation=r.solar_radiation,
        et0_total=r.et0_total,
        soil_temp_0_7cm=r.soil_temp_0_7cm,
        soil_temp_7_28cm=r.soil_temp_7_28cm,
        soil_temp_28_100cm=r.soil_temp_28_100cm,
        soil_temp_100_255cm=r.soil_temp_100_255cm,
        soil_moisture_0_7cm=r.soil_moisture_0_7cm,
        soil_moisture_7_28cm=r.soil_moisture_7_28cm,
        soil_moisture_28_100cm=r.soil_moisture_28_100cm,
        soil_moisture_100_255cm=r.soil_moisture_100_255cm,
    )


# ── Endpoints ─────────────────────────────────────────────────────────


@router.get("/locations", response_model=list[LocationInfo])
async def get_locations():
    """世界時計 + 栽培分析の対象地点一覧。"""
    return [
        LocationInfo(key=k, name=v["name"], lat=v["lat"], lon=v["lon"], tz=v["tz"])
        for k, v in WORLD_LOCATIONS.items()
    ]


@router.get("/fetch", response_model=ERA5Monthly)
async def fetch_monthly(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    year: int = Query(..., ge=1950, le=2026),
    month: int = Query(..., ge=1, le=12),
    source: str = Query(default="open_meteo",
                        description="open_meteo / aws_s3 / cds_api"),
    db: AsyncSession = Depends(get_db),
):
    """1地点・1ヶ月の ERA5 データを取得して DB に保存。"""
    try:
        if source == "open_meteo":
            data = await fetch_era5_open_meteo(lat, lon, year, month)
        elif source == "aws_s3":
            data = await fetch_era5_aws_point(lat, lon, year, month)
            if data is None:
                raise HTTPException(501, "xarray未インストール")
        elif source == "cds_api":
            data = await fetch_era5_land_cds(lat, lon, year, month)
            if data is None:
                raise HTTPException(501, "cdsapi未インストール")
        else:
            raise HTTPException(400, f"不明なソース: {source}")
    except HTTPException:
        raise
    except httpx.HTTPStatusError as e:
        raise HTTPException(502, f"API取得失敗: {e}")
    except Exception as e:
        raise HTTPException(502, f"データ取得失敗: {e}")

    await _upsert(db, data)
    return ERA5Monthly(**data)


@router.get("/climate", response_model=list[ERA5Monthly])
async def query_climate(
    lat: float = Query(None),
    lon: float = Query(None),
    year: int = Query(None),
    month: int = Query(None, ge=1, le=12),
    source: str = Query(None),
    location: str = Query(None, description="定義済み地点キー (例: tokyo, bordeaux)"),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
):
    """保存済みの ERA5 データを検索。"""
    conds = []
    if location:
        loc = get_location(location)
        if not loc:
            raise HTTPException(404, f"地点 '{location}' が見つかりません")
        lat, lon = loc["lat"], loc["lon"]
    if lat is not None and lon is not None:
        conds.append(ERA5ClimateRecord.lat == round(lat, 2))
        conds.append(ERA5ClimateRecord.lon == round(lon, 2))
    if year is not None:
        conds.append(ERA5ClimateRecord.year == year)
    if month is not None:
        conds.append(ERA5ClimateRecord.month == month)
    if source is not None:
        conds.append(ERA5ClimateRecord.source == source)

    stmt = (
        select(ERA5ClimateRecord)
        .where(and_(*conds) if conds else True)
        .order_by(ERA5ClimateRecord.year.desc(), ERA5ClimateRecord.month.desc())
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [_record_to_response(r) for r in rows]


@router.get("/aws/metadata")
async def aws_metadata(
    year: int = Query(..., ge=1950, le=2026),
    month: int = Query(..., ge=1, le=12),
):
    """AWS S3 上の ERA5 変数一覧 + ダウンロード URL。"""
    try:
        return await fetch_era5_aws_metadata(year, month)
    except Exception as e:
        raise HTTPException(502, f"S3メタデータ取得失敗: {e}")


@router.post("/collect", response_model=CollectSummary)
async def collect_batch(
    year_start: int = Query(..., ge=1950, le=2026),
    year_end: int = Query(None, ge=1950, le=2026),
    month_start: int = Query(1, ge=1, le=12),
    month_end: int = Query(12, ge=1, le=12),
    locations: str = Query("all", description="カンマ区切り or 'all'"),
    source: str = Query("open_meteo"),
    db: AsyncSession = Depends(get_db),
):
    """複数地点・期間の一括収集。既に取得済みのものはスキップ。

    例: POST /era5/collect?year_start=2020&year_end=2024&locations=tokyo,roma,bordeaux
    """
    if year_end is None:
        year_end = year_start
    if year_end < year_start:
        raise HTTPException(400, "year_end < year_start")

    if locations == "all":
        targets = list(WORLD_LOCATIONS.items())
    else:
        keys = [k.strip() for k in locations.split(",") if k.strip()]
        targets = []
        for k in keys:
            loc = get_location(k)
            if not loc:
                raise HTTPException(404, f"地点 '{k}' が見つかりません")
            targets.append((k, loc))

    results: list[CollectResult] = []

    for key, loc in targets:
        lat, lon = loc["lat"], loc["lon"]
        for y in range(year_start, year_end + 1):
            for m in range(month_start, month_end + 1):
                # skip if already collected
                existing = await db.execute(
                    select(ERA5ClimateRecord).where(and_(
                        ERA5ClimateRecord.lat == round(lat, 2),
                        ERA5ClimateRecord.lon == round(lon, 2),
                        ERA5ClimateRecord.year == y,
                        ERA5ClimateRecord.month == m,
                        ERA5ClimateRecord.source == source,
                    ))
                )
                if existing.scalar_one_or_none():
                    results.append(CollectResult(
                        location=key, year=y, month=m,
                        source=source, status="skipped", message="取得済み",
                    ))
                    continue

                try:
                    if source == "open_meteo":
                        data = await fetch_era5_open_meteo(lat, lon, y, m)
                    elif source == "aws_s3":
                        data = await fetch_era5_aws_point(lat, lon, y, m)
                        if data is None:
                            results.append(CollectResult(
                                location=key, year=y, month=m,
                                source=source, status="error",
                                message="xarray未インストール",
                            ))
                            continue
                    elif source == "cds_api":
                        data = await fetch_era5_land_cds(lat, lon, y, m)
                        if data is None:
                            results.append(CollectResult(
                                location=key, year=y, month=m,
                                source=source, status="error",
                                message="cdsapi未インストール",
                            ))
                            continue
                    else:
                        results.append(CollectResult(
                            location=key, year=y, month=m,
                            source=source, status="error",
                            message=f"不明ソース: {source}",
                        ))
                        continue

                    await _upsert(db, data)
                    results.append(CollectResult(
                        location=key, year=y, month=m,
                        source=source, status="ok",
                    ))
                except Exception as e:
                    results.append(CollectResult(
                        location=key, year=y, month=m,
                        source=source, status="error",
                        message=str(e)[:200],
                    ))

    ok = sum(1 for r in results if r.status == "ok")
    skip = sum(1 for r in results if r.status == "skipped")
    err = sum(1 for r in results if r.status == "error")
    return CollectSummary(
        total=len(results), ok=ok, skipped=skip, errors=err,
        results=results,
    )


@router.get("/summary")
async def collection_summary(db: AsyncSession = Depends(get_db)):
    """収集状況のサマリー。"""
    total = (await db.execute(
        select(func.count(ERA5ClimateRecord.id))
    )).scalar() or 0

    source_counts = dict((await db.execute(
        select(ERA5ClimateRecord.source, func.count(ERA5ClimateRecord.id))
        .group_by(ERA5ClimateRecord.source)
    )).all())

    year_row = (await db.execute(
        select(func.min(ERA5ClimateRecord.year), func.max(ERA5ClimateRecord.year))
    )).first()

    return {
        "total_records": total,
        "by_source": source_counts,
        "year_range": {
            "min": year_row[0] if year_row else None,
            "max": year_row[1] if year_row else None,
        },
        "predefined_locations": len(WORLD_LOCATIONS),
    }
