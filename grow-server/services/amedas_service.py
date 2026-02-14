"""AMeDAS data fetcher from JMA (Japan Meteorological Agency).

JMA JSON API endpoints:
  - Station list: https://www.jma.go.jp/bosai/amedas/const/amedastable.json
  - Latest time:  https://www.jma.go.jp/bosai/amedas/data/latest_time.txt
  - Point data:   https://www.jma.go.jp/bosai/amedas/data/point/{station_id}/{YYYYMMDD}_{HH}.json
    HH = 00, 03, 06, 09, 12, 15, 18, 21 (3-hour blocks, each containing 10-min intervals)

Data format: each field is [value, quality_flag] where quality_flag 0 = normal.
"""

import logging
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from models.amedas import AmedasStation, AmedasRecord

logger = logging.getLogger(__name__)

JST = timezone(timedelta(hours=9))
BASE_URL = "https://www.jma.go.jp/bosai/amedas"
_HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; GrowGPUServer/0.1)",
}

# 16-direction wind labels
WIND_DIRECTIONS = [
    "", "北", "北北東", "北東", "東北東",
    "東", "東南東", "南東", "南南東",
    "南", "南南西", "南西", "西南西",
    "西", "西北西", "北西", "北北西",
]


def _val(data: dict, key: str):
    """Extract value from AMeDAS [value, quality] pair."""
    entry = data.get(key)
    if entry is None:
        return None
    if isinstance(entry, list) and len(entry) >= 1:
        return entry[0]
    return None


def _dms_to_decimal(dms: list) -> float:
    """Convert [degrees, minutes] to decimal degrees."""
    if isinstance(dms, list) and len(dms) >= 2:
        return dms[0] + dms[1] / 60.0
    return 0.0


# ---------- Station Master ----------


async def fetch_station_table() -> dict:
    """Fetch the full AMeDAS station table from JMA.

    Returns dict: station_id -> station_info
    """
    url = f"{BASE_URL}/const/amedastable.json"
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_HEADERS, timeout=30)
        resp.raise_for_status()
        return resp.json()


async def sync_stations(db: AsyncSession) -> int:
    """Download and upsert all AMeDAS stations into DB.

    Returns number of stations synced.
    """
    raw = await fetch_station_table()
    count = 0

    for station_id, info in raw.items():
        station = AmedasStation(
            station_id=station_id,
            type=info.get("type", ""),
            kj_name=info.get("kjName", ""),
            kn_name=info.get("knName", ""),
            en_name=info.get("enName", ""),
            lat=_dms_to_decimal(info.get("lat", [0, 0])),
            lon=_dms_to_decimal(info.get("lon", [0, 0])),
            alt=info.get("alt", 0),
            elems=info.get("elems", ""),
            updated_at=datetime.utcnow(),
        )
        stmt = sqlite_insert(AmedasStation).values(
            station_id=station.station_id,
            type=station.type,
            kj_name=station.kj_name,
            kn_name=station.kn_name,
            en_name=station.en_name,
            lat=station.lat,
            lon=station.lon,
            alt=station.alt,
            elems=station.elems,
            updated_at=station.updated_at,
        ).on_conflict_do_update(
            index_elements=["station_id"],
            set_={
                "type": station.type,
                "kj_name": station.kj_name,
                "kn_name": station.kn_name,
                "en_name": station.en_name,
                "lat": station.lat,
                "lon": station.lon,
                "alt": station.alt,
                "elems": station.elems,
                "updated_at": station.updated_at,
            },
        )
        await db.execute(stmt)
        count += 1

    await db.commit()
    logger.info("Synced %d AMeDAS stations.", count)
    return count


async def search_stations(
    db: AsyncSession,
    query: str = "",
    lat: float | None = None,
    lon: float | None = None,
    limit: int = 20,
) -> list[AmedasStation]:
    """Search stations by name or proximity."""
    if lat is not None and lon is not None:
        # Order by distance (approximate, good enough for Japan)
        stmt = (
            select(AmedasStation)
            .order_by(
                func.abs(AmedasStation.lat - lat)
                + func.abs(AmedasStation.lon - lon)
            )
            .limit(limit)
        )
    elif query:
        stmt = (
            select(AmedasStation)
            .where(
                AmedasStation.kj_name.contains(query)
                | AmedasStation.kn_name.contains(query)
                | AmedasStation.en_name.ilike(f"%{query}%")
                | (AmedasStation.station_id == query)
            )
            .limit(limit)
        )
    else:
        stmt = select(AmedasStation).limit(limit)

    result = await db.execute(stmt)
    return list(result.scalars().all())


# ---------- Observation Data ----------


async def get_latest_time() -> datetime:
    """Get the latest observation time from JMA."""
    url = f"{BASE_URL}/data/latest_time.txt"
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_HEADERS, timeout=15)
        resp.raise_for_status()
        # Format: "2026-02-09T12:00:00+09:00"
        text = resp.text.strip()
        return datetime.fromisoformat(text)


async def fetch_point_data(
    station_id: str, target_date: datetime
) -> dict:
    """Fetch 3-hour block of point data for a station.

    target_date should be in JST. The HH in the URL is the 3-hour block start:
    00, 03, 06, 09, 12, 15, 18, 21
    """
    # Round down to 3-hour block
    hour_block = (target_date.hour // 3) * 3
    date_str = target_date.strftime("%Y%m%d")
    url = f"{BASE_URL}/data/point/{station_id}/{date_str}_{hour_block:02d}.json"

    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_HEADERS, timeout=30)
        resp.raise_for_status()
        return resp.json()


async def fetch_and_store_point(
    db: AsyncSession,
    station_id: str,
    target_date: datetime,
) -> int:
    """Fetch a 3-hour block and store all records.

    Returns number of records inserted/updated.
    """
    raw = await fetch_point_data(station_id, target_date)
    count = 0

    for time_key, obs in raw.items():
        # time_key format: "20260209120000"
        try:
            observed_at = datetime.strptime(time_key, "%Y%m%d%H%M%S")
        except ValueError:
            continue

        values = dict(
            station_id=station_id,
            observed_at=observed_at,
            temp=_val(obs, "temp"),
            humidity=_val(obs, "humidity"),
            pressure=_val(obs, "pressure"),
            normal_pressure=_val(obs, "normalPressure"),
            wind_speed=_val(obs, "wind"),
            wind_direction=_val(obs, "windDirection"),
            precipitation_10m=_val(obs, "precipitation10m"),
            precipitation_1h=_val(obs, "precipitation1h"),
            precipitation_3h=_val(obs, "precipitation3h"),
            precipitation_24h=_val(obs, "precipitation24h"),
            sun_10m=_val(obs, "sun10m"),
            sun_1h=_val(obs, "sun1h"),
            snow=_val(obs, "snow"),
            snow_1h=_val(obs, "snow1h"),
            snow_6h=_val(obs, "snow6h"),
            snow_12h=_val(obs, "snow12h"),
            snow_24h=_val(obs, "snow24h"),
            visibility=_val(obs, "visibility"),
        )

        stmt = sqlite_insert(AmedasRecord).values(**values).on_conflict_do_update(
            index_elements=["station_id", "observed_at"],
            set_={k: v for k, v in values.items() if k not in ("station_id", "observed_at")},
        )
        await db.execute(stmt)
        count += 1

    await db.commit()
    return count


async def fetch_day(
    db: AsyncSession,
    station_id: str,
    date: datetime,
) -> int:
    """Fetch all 3-hour blocks for a full day. Returns total records."""
    total = 0
    for hour in range(0, 24, 3):
        target = date.replace(hour=hour, minute=0, second=0, microsecond=0)
        try:
            n = await fetch_and_store_point(db, station_id, target)
            total += n
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                # Future block or no data yet
                logger.debug(
                    "No data for %s block %02d:00", station_id, hour
                )
            else:
                raise
    return total
