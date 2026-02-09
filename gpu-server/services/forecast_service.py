"""ECMWF forecast data fetcher via Open-Meteo API.

Open-Meteo provides free ECMWF IFS forecast data including soil temperature
and moisture at multiple depths - very useful for cultivation planning.

API: https://api.open-meteo.com/v1/forecast
Model: ecmwf_ifs
No API key required.
"""

import logging
from datetime import datetime, timezone

import httpx

logger = logging.getLogger(__name__)

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

# All hourly variables we want from ECMWF
HOURLY_VARIABLES = [
    "temperature_2m",
    "relative_humidity_2m",
    "precipitation",
    "weather_code",
    "pressure_msl",
    "wind_speed_10m",
    "wind_direction_10m",
    "wind_gusts_10m",
    "sunshine_duration",
    "surface_temperature",
    # Soil temperature at 4 depths
    "soil_temperature_0_to_7cm",
    "soil_temperature_7_to_28cm",
    "soil_temperature_28_to_100cm",
    "soil_temperature_100_to_255cm",
    # Soil moisture at 4 depths
    "soil_moisture_0_to_7cm",
    "soil_moisture_7_to_28cm",
    "soil_moisture_28_to_100cm",
    "soil_moisture_100_to_255cm",
    "runoff",
]

# WMO Weather Code descriptions (Japanese)
WMO_WEATHER_CODES = {
    0: "快晴",
    1: "晴れ",
    2: "一部曇り",
    3: "曇り",
    45: "霧",
    48: "着氷霧",
    51: "弱い霧雨",
    53: "霧雨",
    55: "強い霧雨",
    56: "弱い着氷霧雨",
    57: "強い着氷霧雨",
    61: "弱い雨",
    63: "雨",
    65: "強い雨",
    66: "弱い着氷雨",
    67: "強い着氷雨",
    71: "弱い雪",
    73: "雪",
    75: "強い雪",
    77: "霧雪",
    80: "弱いにわか雨",
    81: "にわか雨",
    82: "強いにわか雨",
    85: "弱いにわか雪",
    86: "強いにわか雪",
    95: "雷雨",
    96: "雹を伴う雷雨",
    99: "強い雹を伴う雷雨",
}


def weather_code_label(code: int | None) -> str:
    if code is None:
        return ""
    return WMO_WEATHER_CODES.get(int(code), f"不明({code})")


async def fetch_ecmwf_forecast(
    lat: float,
    lon: float,
    forecast_days: int = 7,
    past_days: int = 0,
) -> dict:
    """Fetch ECMWF IFS forecast from Open-Meteo.

    Returns the raw JSON response from Open-Meteo with hourly data.
    """
    params = {
        "latitude": lat,
        "longitude": lon,
        "hourly": ",".join(HOURLY_VARIABLES),
        "models": "ecmwf_ifs",
        "wind_speed_unit": "ms",
        "timezone": "Asia/Tokyo",
        "forecast_days": forecast_days,
        "past_days": past_days,
    }

    async with httpx.AsyncClient() as client:
        resp = await client.get(OPEN_METEO_URL, params=params, timeout=30)
        resp.raise_for_status()
        return resp.json()


def parse_forecast(raw: dict) -> list[dict]:
    """Parse Open-Meteo response into a list of hourly records.

    Returns list of dicts, one per hour, with all variables.
    """
    hourly = raw.get("hourly", {})
    times = hourly.get("time", [])

    records = []
    for i, time_str in enumerate(times):
        record = {"time": time_str}
        for var in HOURLY_VARIABLES:
            values = hourly.get(var, [])
            record[var] = values[i] if i < len(values) else None
        record["weather_label"] = weather_code_label(record.get("weather_code"))
        records.append(record)

    return records


def summarize_forecast_day(records: list[dict], date_str: str) -> dict:
    """Summarize a day's worth of hourly records."""
    day_records = [r for r in records if r["time"].startswith(date_str)]
    if not day_records:
        return {"date": date_str, "count": 0}

    def _vals(key):
        return [r[key] for r in day_records if r.get(key) is not None]

    def _avg(vals):
        return round(sum(vals) / len(vals), 1) if vals else None

    def _rnd(val, d=1):
        return round(val, d) if val is not None else None

    temps = _vals("temperature_2m")
    soil_t_shallow = _vals("soil_temperature_0_to_7cm")
    soil_m_shallow = _vals("soil_moisture_0_to_7cm")
    precip = _vals("precipitation")
    sunshine = _vals("sunshine_duration")
    wind = _vals("wind_speed_10m")

    # Dominant weather: most common non-zero code, or 0
    codes = _vals("weather_code")
    dominant_code = 0
    if codes:
        non_zero = [int(c) for c in codes if c > 0]
        if non_zero:
            dominant_code = max(set(non_zero), key=non_zero.count)
        else:
            dominant_code = 0

    return {
        "date": date_str,
        "count": len(day_records),
        "weather_code": dominant_code,
        "weather_label": weather_code_label(dominant_code),
        "temp_min": _rnd(min(temps)) if temps else None,
        "temp_max": _rnd(max(temps)) if temps else None,
        "temp_avg": _avg(temps),
        "soil_temp_shallow_avg": _avg(soil_t_shallow),
        "soil_moisture_shallow_avg": _avg(soil_m_shallow),
        "precipitation_total": _rnd(sum(precip)) if precip else None,
        "sunshine_total_min": _rnd(sum(sunshine) / 60.0) if sunshine else None,
        "wind_speed_avg": _avg(wind),
        "wind_speed_max": _rnd(max(wind)) if wind else None,
    }
