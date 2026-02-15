"""AMeDAS 定期データ取得スケジューラー（Parquet 版）。

設定された地点（最大3箇所）のデータを1日1回 JMA から取得。
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path

from config import settings
from services.amedas_service import fetch_day_to_parquet, sync_stations

logger = logging.getLogger(__name__)

JST = timezone(timedelta(hours=9))
_FETCH_HOUR = 2  # 深夜2時 JST


def _seconds_until_next_fetch() -> int:
    now = datetime.now(JST)
    tomorrow_2am = (now + timedelta(days=1)).replace(
        hour=_FETCH_HOUR, minute=0, second=0, microsecond=0,
    )
    return int((tomorrow_2am - now).total_seconds())


def _station_dir(station_id: str) -> Path:
    return Path(settings.data_dir) / "amedas" / station_id


def _stations_file() -> Path:
    return Path(settings.data_dir) / "amedas" / "stations.json"


async def fetch_all_stations(station_ids: list[str]) -> dict[str, int]:
    """全登録地点の当日データを取得。"""
    now = datetime.now(JST)
    results = {}
    for sid in station_ids:
        sid = sid.strip()
        try:
            count = await fetch_day_to_parquet(_station_dir(sid), sid, now)
            results[sid] = count
            logger.info("AMeDAS fetch: station=%s date=%s records=%d",
                        sid, now.strftime("%Y-%m-%d"), count)
        except Exception as e:
            results[sid] = 0
            logger.warning("AMeDAS fetch failed: station=%s error=%s", sid, e)
    return results


async def amedas_scheduler(station_ids: list[str]) -> None:
    """1日1回 AMeDAS データを取得するバックグラウンドタスク。"""
    logger.info("AMeDAS scheduler started: stations=%s (daily at %02d:00 JST)",
                station_ids, _FETCH_HOUR)

    # 起動後5分待つ
    await asyncio.sleep(5 * 60)

    # 地点マスター同期
    try:
        await sync_stations(_stations_file())
        logger.info("AMeDAS station master synced.")
    except Exception as e:
        logger.warning("AMeDAS station sync failed: %s", e)

    # 初回取得
    await fetch_all_stations(station_ids)

    # 毎日深夜2:00 JST
    while True:
        wait = _seconds_until_next_fetch()
        logger.info("AMeDAS next fetch in %d seconds", wait)
        await asyncio.sleep(wait)
        try:
            await fetch_all_stations(station_ids)
        except Exception as e:
            logger.error("AMeDAS scheduler error: %s", e)
