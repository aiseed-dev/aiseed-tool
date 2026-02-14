"""SwitchBot Cloud API v1.1 ポーリングサービス。

SwitchBot の温湿度計（Meter / MeterPlus / WoIOSensor）から
定期的にデータを取得してセンサー共通フォーマットで保存する。

認証: トークン + シークレットキーから HMAC-SHA256 署名を生成。
API制限: 1日10,000回まで（個人利用のみ）。

必要な設定（.env）:
  CLIMATE_SWITCHBOT_TOKEN=your-token
  CLIMATE_SWITCHBOT_SECRET=your-secret
  CLIMATE_SWITCHBOT_DEVICES=DEVICE_ID1,DEVICE_ID2
"""

import hashlib
import hmac
import base64
import time
import uuid
import logging
from datetime import datetime, timezone

import httpx

logger = logging.getLogger(__name__)

API_BASE = "https://api.switch-bot.com/v1.1"

# 屋外対応デバイスタイプ
OUTDOOR_TYPES = {"WoIOSensor"}


def _make_headers(token: str, secret: str) -> dict:
    """SwitchBot API v1.1 認証ヘッダーを生成。"""
    t = str(int(time.time() * 1000))
    nonce = uuid.uuid4().hex
    string_to_sign = f"{token}{t}{nonce}"
    sign = base64.b64encode(
        hmac.new(
            secret.encode("utf-8"),
            string_to_sign.encode("utf-8"),
            hashlib.sha256,
        ).digest()
    ).decode("utf-8")
    return {
        "Authorization": token,
        "t": t,
        "nonce": nonce,
        "sign": sign,
        "Content-Type": "application/json",
    }


async def get_devices(token: str, secret: str) -> list[dict]:
    """デバイス一覧を取得。温湿度計のみフィルタして返す。"""
    meter_types = {"Meter", "MeterPlus", "MeterPro", "MeterPro(CO2)", "WoIOSensor"}
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{API_BASE}/devices",
            headers=_make_headers(token, secret),
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()

    devices = []
    for dev in data.get("body", {}).get("deviceList", []):
        if dev.get("deviceType") in meter_types:
            devices.append({
                "device_id": dev["deviceId"],
                "device_name": dev.get("deviceName", ""),
                "device_type": dev["deviceType"],
            })
    return devices


async def get_device_status(token: str, secret: str, device_id: str) -> dict | None:
    """指定デバイスのステータスを取得。"""
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{API_BASE}/devices/{device_id}/status",
            headers=_make_headers(token, secret),
            timeout=10,
        )
        if resp.status_code != 200:
            logger.warning("SwitchBot API error: %d %s", resp.status_code, resp.text)
            return None
        data = resp.json()

    body = data.get("body", {})
    if not body:
        return None

    device_type = body.get("deviceType", "")
    is_outdoor = device_type in OUTDOOR_TYPES
    temp = body.get("temperature")
    humidity = body.get("humidity")

    record = {
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "source": "switchbot",
        "station_type": device_type,
    }

    if is_outdoor:
        record["temp_outdoor_c"] = temp
        record["humidity_outdoor"] = humidity
    else:
        record["temp_indoor_c"] = temp
        record["humidity_indoor"] = humidity

    return record


async def poll_all_devices(token: str, secret: str, device_ids: list[str]) -> list[dict]:
    """指定デバイスすべてのステータスを取得してレコードリストを返す。"""
    records = []
    for device_id in device_ids:
        try:
            record = await get_device_status(token, secret, device_id)
            if record:
                records.append(record)
                logger.info("SwitchBot data: device=%s, temp=%s",
                            device_id, record.get("temp_outdoor_c") or record.get("temp_indoor_c"))
        except Exception as e:
            logger.error("SwitchBot poll error for %s: %s", device_id, e)
    return records
