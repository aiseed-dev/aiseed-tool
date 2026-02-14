"""AMeDAS 定期データ取得スケジューラー。

設定された地点（最大3箇所）の気象データを1日1回 JMA から取得し DB に保存する。
積算温度の計算に必要な連続データを自動で蓄積する。
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from database import async_session
from services.amedas_service import fetch_day, sync_stations

logger = logging.getLogger(__name__)

JST = timezone(timedelta(hours=9))

# 1日 = 86400秒
_ONE_DAY = 86400


async def fetch_all_stations(station_ids: list[str]) -> dict[str, int]:
    """全登録地点の当日データを取得する。手動更新からも呼ばれる。"""
    now = datetime.now(JST)
    results = {}

    async with async_session() as db:
        for sid in station_ids:
            sid = sid.strip()
            try:
                count = await fetch_day(db, sid, now)
                results[sid] = count
                logger.info("AMeDAS fetch: station=%s date=%s records=%d",
                            sid, now.strftime("%Y-%m-%d"), count)
            except Exception as e:
                results[sid] = 0
                logger.warning("AMeDAS fetch failed: station=%s error=%s", sid, e)

    return results


async def amedas_scheduler(station_ids: list[str]) -> None:
    """1日1回 AMeDAS データを取得するバックグラウンドタスク。"""
    logger.info("AMeDAS scheduler started: stations=%s (daily)", station_ids)

    # 初回は地点マスターを同期
    try:
        async with async_session() as db:
            await sync_stations(db)
            logger.info("AMeDAS station master synced.")
    except Exception as e:
        logger.warning("AMeDAS station sync failed: %s", e)

    # 初回取得
    await fetch_all_stations(station_ids)

    # 以降は1日1回
    while True:
        await asyncio.sleep(_ONE_DAY)
        try:
            await fetch_all_stations(station_ids)
        except Exception as e:
            logger.error("AMeDAS scheduler error: %s", e)
