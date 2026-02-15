"""SwitchBot 定期ポーリングスケジューラー。

5分間隔でデバイスのステータスを取得し Parquet に保存。
API制限（1日10,000回）を考慮して、デバイス数 × 288回/日 程度。
3デバイスなら 864回/日 で十分余裕がある。
"""

import asyncio
import logging
from pathlib import Path

from config import settings
from services.switchbot_service import poll_all_devices
from storage.parquet_store import append_records

logger = logging.getLogger(__name__)

POLL_INTERVAL = 300  # 5分


async def switchbot_scheduler(
    token: str,
    secret: str,
    device_ids: list[str],
):
    """SwitchBot ポーリングループ。"""
    sensor_dir = Path(settings.data_dir) / "sensor"
    logger.info("SwitchBot scheduler started: %d devices, interval=%ds",
                len(device_ids), POLL_INTERVAL)

    while True:
        try:
            records = await poll_all_devices(token, secret, device_ids)
            if records:
                count = append_records(sensor_dir, records)
                logger.info("SwitchBot: stored %d records", count)
        except Exception as e:
            logger.error("SwitchBot scheduler error: %s", e)

        await asyncio.sleep(POLL_INTERVAL)
