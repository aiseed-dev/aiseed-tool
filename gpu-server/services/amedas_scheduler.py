"""AMeDAS 定期データ取得スケジューラー。

設定された地点の気象データを定期的に JMA から取得し DB に保存する。
積算温度の計算に必要な連続データを自動で蓄積する。
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from database import async_session
from services.amedas_service import fetch_day, sync_stations

logger = logging.getLogger(__name__)

JST = timezone(timedelta(hours=9))


async def _fetch_stations(station_ids: list[str]) -> None:
    """指定地点の当日データを取得する。"""
    now = datetime.now(JST)

    async with async_session() as db:
        for sid in station_ids:
            try:
                count = await fetch_day(db, sid.strip(), now)
                logger.info("AMeDAS fetch: station=%s date=%s records=%d",
                            sid.strip(), now.strftime("%Y-%m-%d"), count)
            except Exception as e:
                logger.warning("AMeDAS fetch failed: station=%s error=%s",
                               sid.strip(), e)


async def amedas_scheduler(station_ids: list[str], interval_minutes: int) -> None:
    """定期的に AMeDAS データを取得するバックグラウンドタスク。"""
    logger.info(
        "AMeDAS scheduler started: stations=%s interval=%d min",
        station_ids, interval_minutes,
    )

    # 初回は地点マスターを同期
    try:
        async with async_session() as db:
            await sync_stations(db)
            logger.info("AMeDAS station master synced.")
    except Exception as e:
        logger.warning("AMeDAS station sync failed: %s", e)

    while True:
        try:
            await _fetch_stations(station_ids)
        except Exception as e:
            logger.error("AMeDAS scheduler error: %s", e)

        await asyncio.sleep(interval_minutes * 60)
