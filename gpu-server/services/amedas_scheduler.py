"""AMeDAS 定期データ取得スケジューラー。

設定された地点（最大3箇所）の気象データを1日1回 JMA から取得し DB に保存する。
積算温度の計算に必要な連続データを自動で蓄積する。

常時稼働サーバーの場合、毎日深夜2:00 (JST) に取得を実行する。
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from database import async_session
from services.amedas_service import fetch_day, sync_stations

logger = logging.getLogger(__name__)

JST = timezone(timedelta(hours=9))

# 毎日の取得時刻（JST）
_FETCH_HOUR = 2  # 深夜2時


def _seconds_until_next_fetch() -> int:
    """次の取得時刻（翌日 2:00 JST）までの秒数を返す。"""
    now = datetime.now(JST)
    tomorrow_2am = (now + timedelta(days=1)).replace(
        hour=_FETCH_HOUR, minute=0, second=0, microsecond=0,
    )
    return int((tomorrow_2am - now).total_seconds())


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
    """1日1回 AMeDAS データを取得するバックグラウンドタスク。

    起動直後はネットワークやシステムが安定していない可能性があるため、
    5分待ってから初回取得を行う。以降は毎日深夜2:00 (JST) に取得する。
    """
    logger.info("AMeDAS scheduler started: stations=%s (daily at %02d:00 JST)",
                station_ids, _FETCH_HOUR)

    # 起動後5分待つ（電源ON直後のネットワーク安定待ち）
    await asyncio.sleep(5 * 60)

    # 地点マスターを同期
    try:
        async with async_session() as db:
            await sync_stations(db)
            logger.info("AMeDAS station master synced.")
    except Exception as e:
        logger.warning("AMeDAS station sync failed: %s", e)

    # 初回取得（起動時に最新データを確保）
    await fetch_all_stations(station_ids)

    # 以降は毎日深夜2:00 (JST) に取得
    while True:
        wait = _seconds_until_next_fetch()
        logger.info("AMeDAS next fetch in %d seconds (%s JST)",
                    wait, (datetime.now(JST) + timedelta(seconds=wait)).strftime("%Y-%m-%d %H:%M"))
        await asyncio.sleep(wait)
        try:
            await fetch_all_stations(station_ids)
        except Exception as e:
            logger.error("AMeDAS scheduler error: %s", e)
