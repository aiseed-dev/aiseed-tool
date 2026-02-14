"""積算温度（Growing Degree Days）API。

ERA5 NetCDF の過去データから計算。AMeDAS は使わない。
Open-Meteo Archive API から日次 temp_min / temp_max を取得し、
GDD = max((temp_max + temp_min) / 2 - base_temp, 0) の累計を返す。
"""

import logging
from datetime import datetime, timedelta, timezone

import httpx
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/gdd", tags=["gdd"])

OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"


class GddDayEntry(BaseModel):
    date: str
    temp_min: float | None = None
    temp_max: float | None = None
    temp_avg: float | None = None
    gdd: float = 0.0
    cumulative: float = 0.0


class GddResponse(BaseModel):
    lat: float
    lon: float
    base_temp: float
    start_date: str
    end_date: str
    total_gdd: float
    days: list[GddDayEntry]


@router.get("/calc", response_model=GddResponse)
async def calc_gdd(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    start_date: str = Query(..., description="起算日 YYYY-MM-DD（播種日・定植日）"),
    end_date: str = Query(default="", description="終了日（空なら昨日）"),
    base_temp: float = Query(default=10.0, description="基準温度 ℃"),
):
    """積算温度を計算する。

    Open-Meteo Archive API (ERA5) の日次 temp_min/temp_max から算出。
    世界中どこでも使える。

    - base_temp=10: 一般的な野菜（トマト、ナスなど）
    - base_temp=5: 冷涼作物（レタス、ほうれん草など）
    - base_temp=15: 熱帯性作物（オクラなど）
    """
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="開始日の形式が正しくありません")

    if end_date:
        try:
            end = datetime.strptime(end_date, "%Y-%m-%d")
        except ValueError:
            raise HTTPException(status_code=400, detail="終了日の形式が正しくありません")
    else:
        # ERA5 は数日遅延があるので昨日まで
        end = datetime.now(timezone.utc) - timedelta(days=1)

    # Open-Meteo Archive API から日次データ取得
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": start.strftime("%Y-%m-%d"),
        "end_date": end.strftime("%Y-%m-%d"),
        "daily": "temperature_2m_max,temperature_2m_min",
        "timezone": "auto",
    }

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(OPEN_METEO_ARCHIVE_URL, params=params, timeout=30)
            resp.raise_for_status()
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"Open-Meteo Archive 取得失敗: {e}")

    data = resp.json()
    daily = data.get("daily", {})
    dates = daily.get("time", [])
    temp_maxs = daily.get("temperature_2m_max", [])
    temp_mins = daily.get("temperature_2m_min", [])

    # GDD 計算
    days: list[GddDayEntry] = []
    cumulative = 0.0

    for i, d in enumerate(dates):
        t_max = temp_maxs[i] if i < len(temp_maxs) else None
        t_min = temp_mins[i] if i < len(temp_mins) else None

        if t_max is not None and t_min is not None:
            t_avg = round((t_max + t_min) / 2, 1)
            gdd = max(t_avg - base_temp, 0.0)
        else:
            t_avg = None
            gdd = 0.0

        cumulative += gdd
        days.append(GddDayEntry(
            date=d,
            temp_min=t_min,
            temp_max=t_max,
            temp_avg=t_avg,
            gdd=round(gdd, 1),
            cumulative=round(cumulative, 1),
        ))

    return GddResponse(
        lat=lat,
        lon=lon,
        base_temp=base_temp,
        start_date=start.strftime("%Y-%m-%d"),
        end_date=end.strftime("%Y-%m-%d"),
        total_gdd=round(cumulative, 1),
        days=days,
    )
