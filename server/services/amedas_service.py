"""AMeDAS データ取得（JMA API → Parquet ストレージ）。

地点マスターは JSON ファイル、観測データは Parquet で保存。
"""

import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx

from storage.parquet_store import append_records

logger = logging.getLogger(__name__)

JST = timezone(timedelta(hours=9))
BASE_URL = "https://www.jma.go.jp/bosai/amedas"
_HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; ClimateServer/0.1)"}

# 16方位ラベル
WIND_DIRECTIONS = [
    "", "北", "北北東", "北東", "東北東",
    "東", "東南東", "南東", "南南東",
    "南", "南南西", "南西", "西南西",
    "西", "西北西", "北西", "北北西",
]


def _val(data: dict, key: str):
    """AMeDAS [value, quality] ペアから値を抽出。"""
    entry = data.get(key)
    if entry is None:
        return None
    if isinstance(entry, list) and len(entry) >= 1:
        return entry[0]
    return None


def _dms_to_decimal(dms: list) -> float:
    """[度, 分] → 10進度"""
    if isinstance(dms, list) and len(dms) >= 2:
        return dms[0] + dms[1] / 60.0
    return 0.0


# ---------- 地点マスター ----------

async def fetch_station_table() -> dict:
    """JMA から全 AMeDAS 地点テーブルを取得。"""
    url = f"{BASE_URL}/const/amedastable.json"
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_HEADERS, timeout=30)
        resp.raise_for_status()
        return resp.json()


async def sync_stations(stations_file: Path) -> int:
    """地点マスターを JSON ファイルに保存。"""
    raw = await fetch_station_table()
    stations = {}
    for station_id, info in raw.items():
        stations[station_id] = {
            "station_id": station_id,
            "type": info.get("type", ""),
            "kj_name": info.get("kjName", ""),
            "kn_name": info.get("knName", ""),
            "en_name": info.get("enName", ""),
            "lat": _dms_to_decimal(info.get("lat", [0, 0])),
            "lon": _dms_to_decimal(info.get("lon", [0, 0])),
            "alt": info.get("alt", 0),
            "elems": info.get("elems", ""),
        }

    stations_file.parent.mkdir(parents=True, exist_ok=True)
    with open(stations_file, "w", encoding="utf-8") as f:
        json.dump(stations, f, ensure_ascii=False, indent=1)

    logger.info("Synced %d AMeDAS stations to %s", len(stations), stations_file)
    return len(stations)


def search_stations_from_file(
    stations_file: Path,
    query: str = "",
    lat: float | None = None,
    lon: float | None = None,
    limit: int = 20,
) -> list[dict]:
    """JSON ファイルから地点検索。"""
    with open(stations_file, encoding="utf-8") as f:
        stations = json.load(f)

    items = list(stations.values())

    if lat is not None and lon is not None:
        items.sort(key=lambda s: abs(s["lat"] - lat) + abs(s["lon"] - lon))
    elif query:
        items = [
            s for s in items
            if query in s.get("kj_name", "")
            or query in s.get("kn_name", "")
            or query.lower() in s.get("en_name", "").lower()
            or s.get("station_id", "") == query
        ]

    return items[:limit]


# ---------- 観測データ取得 ----------

async def fetch_point_data(station_id: str, target_date: datetime) -> dict:
    """3時間ブロックのデータを JMA から取得。"""
    hour_block = (target_date.hour // 3) * 3
    date_str = target_date.strftime("%Y%m%d")
    url = f"{BASE_URL}/data/point/{station_id}/{date_str}_{hour_block:02d}.json"

    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_HEADERS, timeout=30)
        resp.raise_for_status()
        return resp.json()


async def fetch_day_to_parquet(
    station_dir: Path,
    station_id: str,
    date: datetime,
) -> int:
    """1日分のデータを取得して Parquet に保存。"""
    all_records = []

    for hour in range(0, 24, 3):
        target = date.replace(hour=hour, minute=0, second=0, microsecond=0)
        try:
            raw = await fetch_point_data(station_id, target)
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                logger.debug("No data for %s block %02d:00", station_id, hour)
                continue
            raise

        for time_key, obs in raw.items():
            try:
                observed_at = datetime.strptime(time_key, "%Y%m%d%H%M%S").replace(tzinfo=timezone.utc)
            except ValueError:
                continue

            all_records.append({
                "observed_at": observed_at.isoformat(),
                "station_id": station_id,
                "temp": _val(obs, "temp"),
                "humidity": _val(obs, "humidity"),
                "pressure": _val(obs, "pressure"),
                "normal_pressure": _val(obs, "normalPressure"),
                "wind_speed": _val(obs, "wind"),
                "wind_direction": _val(obs, "windDirection"),
                "precipitation_10m": _val(obs, "precipitation10m"),
                "precipitation_1h": _val(obs, "precipitation1h"),
                "precipitation_3h": _val(obs, "precipitation3h"),
                "precipitation_24h": _val(obs, "precipitation24h"),
                "sun_10m": _val(obs, "sun10m"),
                "sun_1h": _val(obs, "sun1h"),
                "snow": _val(obs, "snow"),
                "snow_1h": _val(obs, "snow1h"),
                "snow_6h": _val(obs, "snow6h"),
                "snow_12h": _val(obs, "snow12h"),
                "snow_24h": _val(obs, "snow24h"),
                "visibility": _val(obs, "visibility"),
            })

    if not all_records:
        return 0

    return append_records(station_dir, all_records)


async def get_latest_time() -> datetime:
    """JMA から最新の観測時刻を取得。"""
    url = f"{BASE_URL}/data/latest_time.txt"
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_HEADERS, timeout=15)
        resp.raise_for_status()
        return datetime.fromisoformat(resp.text.strip())
