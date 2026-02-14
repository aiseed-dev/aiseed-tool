"""ERA5 climate data fetcher — daily resolution, xarray output.

Source 1: Open-Meteo Historical API (immediate, no key)
  - ERA5 + ERA5-Land blend, 0.25°
  - https://archive-api.open-meteo.com/v1/archive
  - Returns daily data directly as xarray.Dataset

Source 2: AWS S3 nsf-ncar-era5 bucket (bulk, no key)
  - ERA5 0.25°, NetCDF
  - Requires: xarray h5netcdf s3fs

Source 3: CDS API (account required)
  - ERA5-Land monthly means, 0.1°
  - Requires: cdsapi + ~/.cdsapirc
"""

import logging
import calendar
from typing import Optional

import httpx
import numpy as np
import pandas as pd
import xarray as xr

logger = logging.getLogger(__name__)

# ── 農業地域プリセット ──────────────────────────────────────────────
# 大都市ではなく、実際に農地がある場所の座標。
# ユーザーの圃場座標を直接使うのが基本だが、
# 一括取得・比較用にプリセットを提供する。

FARM_PRESETS: dict[str, dict] = {
    # ── 北海道 ──
    "tokachi":      {"lat": 42.92, "lon": 143.20, "name": "十勝（帯広）",     "tz": "Asia/Tokyo",
                     "note": "畑作・酪農の中心。小麦・じゃがいも・ビート"},
    "kamikawa":     {"lat": 43.77, "lon": 142.37, "name": "上川（旭川）",     "tz": "Asia/Tokyo",
                     "note": "日本最大の米作地帯のひとつ"},
    "sorachi":      {"lat": 43.34, "lon": 141.97, "name": "空知（岩見沢）",   "tz": "Asia/Tokyo",
                     "note": "北海道の米どころ"},
    "furano":       {"lat": 43.34, "lon": 142.38, "name": "富良野",           "tz": "Asia/Tokyo",
                     "note": "メロン・ラベンダー・野菜"},
    # ── 東北 ──
    "shonai":       {"lat": 38.91, "lon": 139.85, "name": "庄内平野（鶴岡）", "tz": "Asia/Tokyo",
                     "note": "つや姫・はえぬきの産地"},
    "yokote":       {"lat": 39.31, "lon": 140.55, "name": "横手（秋田）",     "tz": "Asia/Tokyo",
                     "note": "あきたこまち産地"},
    # ── 関東 ──
    "chiba_sanbu":  {"lat": 35.60, "lon": 140.40, "name": "千葉県山武",       "tz": "Asia/Tokyo",
                     "note": "有機農業が盛んな地域"},
    "saitama_kumagaya": {"lat": 36.15, "lon": 139.39, "name": "埼玉県熊谷",   "tz": "Asia/Tokyo",
                     "note": "深谷ねぎ・ブロッコリー"},
    "ibaraki_tsukuba":  {"lat": 36.08, "lon": 140.08, "name": "茨城県つくば",  "tz": "Asia/Tokyo",
                     "note": "レタス・れんこん・メロン"},
    "tochigi_nasu":     {"lat": 36.97, "lon": 140.05, "name": "栃木県那須",    "tz": "Asia/Tokyo",
                     "note": "酪農・高原野菜"},
    # ── 甲信越・北陸 ──
    "nagano_saku":  {"lat": 36.25, "lon": 138.48, "name": "長野県佐久",       "tz": "Asia/Tokyo",
                     "note": "高原野菜レタス・ブロッコリー"},
    "niigata_echigo": {"lat": 37.90, "lon": 139.02, "name": "新潟県魚沼",     "tz": "Asia/Tokyo",
                     "note": "コシヒカリの最高産地"},
    # ── 東海 ──
    "shizuoka_makinohara": {"lat": 34.73, "lon": 138.23, "name": "静岡県牧之原", "tz": "Asia/Tokyo",
                     "note": "茶の一大産地"},
    "aichi_tahara": {"lat": 34.65, "lon": 137.17, "name": "愛知県田原",       "tz": "Asia/Tokyo",
                     "note": "農業産出額日本一の市（キャベツ・菊）"},
    # ── 近畿 ──
    "nara_yamato":  {"lat": 34.51, "lon": 135.83, "name": "奈良県大和高原",   "tz": "Asia/Tokyo",
                     "note": "大和野菜の産地"},
    # ── 中国・四国 ──
    "okayama_kibichuo": {"lat": 34.83, "lon": 133.77, "name": "岡山県吉備中央", "tz": "Asia/Tokyo",
                     "note": "ぶどう・もも産地近郊"},
    "kochi_nankoku":    {"lat": 33.57, "lon": 133.63, "name": "高知県南国",    "tz": "Asia/Tokyo",
                     "note": "ナス・ピーマンなどハウス園芸"},
    # ── 九州 ──
    "kumamoto_aso": {"lat": 32.88, "lon": 131.10, "name": "熊本県阿蘇",       "tz": "Asia/Tokyo",
                     "note": "高原野菜・酪農"},
    "miyazaki_saito": {"lat": 32.10, "lon": 131.40, "name": "宮崎県西都",     "tz": "Asia/Tokyo",
                     "note": "ピーマン・マンゴー"},
    # ── 沖縄 ──
    "okinawa_nago": {"lat": 26.59, "lon": 127.97, "name": "沖縄県名護",       "tz": "Asia/Tokyo",
                     "note": "ゴーヤー・サトウキビ・パイナップル"},
    # ── イタリア（伝統野菜産地） ──
    "campania_agro": {"lat": 40.68, "lon": 14.98, "name": "カンパーニャ アグロ・ノチェリーノ",
                      "tz": "Europe/Rome", "note": "サンマルツァーノトマトDOP産地"},
    "puglia_foggia": {"lat": 41.46, "lon": 15.54, "name": "プーリア フォッジャ平野",
                      "tz": "Europe/Rome", "note": "イタリア最大の穀倉地帯・トマト"},
    "sicilia_ragusa": {"lat": 36.93, "lon": 14.73, "name": "シチリア ラグーザ",
                       "tz": "Europe/Rome", "note": "ミニトマト・ナス・ズッキーニ"},
    "toscana_maremma": {"lat": 42.76, "lon": 11.11, "name": "トスカーナ マレンマ",
                        "tz": "Europe/Rome", "note": "有機農業先進地域"},
}


# ═══════════════════════════════════════════════════════════════════════
# Source 1: Open-Meteo Historical API — daily xarray output
# ═══════════════════════════════════════════════════════════════════════

OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"

# Daily variables from Open-Meteo
_DAILY_VARS = [
    "temperature_2m_max", "temperature_2m_min", "temperature_2m_mean",
    "precipitation_sum", "rain_sum", "snowfall_sum",
    "wind_speed_10m_max", "wind_gusts_10m_max",
    "shortwave_radiation_sum", "et0_fao_evapotranspiration",
    "sunshine_duration",
]

# Hourly variables (aggregated to daily mean)
_HOURLY_VARS = [
    "relative_humidity_2m", "surface_pressure",
    "soil_temperature_0_to_7cm", "soil_temperature_7_to_28cm",
    "soil_temperature_28_to_100cm", "soil_temperature_100_to_255cm",
    "soil_moisture_0_to_7cm", "soil_moisture_7_to_28cm",
    "soil_moisture_28_to_100cm", "soil_moisture_100_to_255cm",
]

# Map Open-Meteo names → our NetCDF variable names
_DAILY_RENAME = {
    "temperature_2m_max": "temp_max",
    "temperature_2m_min": "temp_min",
    "temperature_2m_mean": "temp_mean",
    "precipitation_sum": "precipitation",
    "rain_sum": "rain",
    "snowfall_sum": "snowfall",
    "wind_speed_10m_max": "wind_speed_max",
    "wind_gusts_10m_max": "wind_gusts_max",
    "shortwave_radiation_sum": "shortwave_radiation",
    "et0_fao_evapotranspiration": "et0",
    "sunshine_duration": "sunshine_hours",
}

_HOURLY_RENAME = {
    "relative_humidity_2m": "humidity_mean",
    "surface_pressure": "pressure_mean",
    "soil_temperature_0_to_7cm": "soil_temp_0_7cm",
    "soil_temperature_7_to_28cm": "soil_temp_7_28cm",
    "soil_temperature_28_to_100cm": "soil_temp_28_100cm",
    "soil_temperature_100_to_255cm": "soil_temp_100_255cm",
    "soil_moisture_0_to_7cm": "soil_moisture_0_7cm",
    "soil_moisture_7_to_28cm": "soil_moisture_7_28cm",
    "soil_moisture_28_to_100cm": "soil_moisture_28_100cm",
    "soil_moisture_100_to_255cm": "soil_moisture_100_255cm",
}


async def fetch_daily_open_meteo(
    lat: float, lon: float,
    date_start: str, date_end: str,
) -> xr.Dataset:
    """Fetch daily ERA5 data via Open-Meteo and return as xarray.Dataset.

    Args:
        lat, lon: Location coordinates
        date_start: "YYYY-MM-DD"
        date_end: "YYYY-MM-DD"

    Returns:
        xr.Dataset with dim=(time,) and daily climate variables.
    """
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": date_start,
        "end_date": date_end,
        "daily": ",".join(_DAILY_VARS),
        "hourly": ",".join(_HOURLY_VARS),
        "wind_speed_unit": "ms",
        "timezone": "UTC",
    }
    async with httpx.AsyncClient() as client:
        resp = await client.get(OPEN_METEO_ARCHIVE_URL, params=params, timeout=60)
        resp.raise_for_status()
        raw = resp.json()

    return _build_daily_dataset(raw, lat, lon)


def _build_daily_dataset(raw: dict, lat: float, lon: float) -> xr.Dataset:
    """Convert Open-Meteo JSON to xarray.Dataset with daily resolution."""
    daily = raw.get("daily", {})
    hourly = raw.get("hourly", {})

    # Build time coordinate from daily data
    dates = pd.to_datetime(daily.get("time", []))
    n_days = len(dates)

    # --- Daily variables (already daily) ---
    data_vars = {}
    for om_name, nc_name in _DAILY_RENAME.items():
        values = daily.get(om_name, [])
        if values and len(values) == n_days:
            arr = np.array(values, dtype=np.float32)
            # sunshine_duration: seconds → hours
            if om_name == "sunshine_duration":
                arr = arr / 3600.0
            # pressure: hPa conversion (Open-Meteo already returns hPa for daily)
            data_vars[nc_name] = (["time"], arr)

    # --- Hourly variables → aggregate to daily mean ---
    if hourly and hourly.get("time"):
        hourly_dates = pd.to_datetime(hourly["time"])
        for om_name, nc_name in _HOURLY_RENAME.items():
            h_values = hourly.get(om_name, [])
            if h_values and len(h_values) == len(hourly_dates):
                h_arr = np.array(h_values, dtype=np.float32)
                # pressure_mean: hPa (Open-Meteo returns hPa for hourly surface_pressure)
                h_series = pd.Series(h_arr, index=hourly_dates)
                daily_mean = h_series.resample("D").mean()
                # Align to our date range
                daily_mean = daily_mean.reindex(dates)
                data_vars[nc_name] = (["time"], daily_mean.values.astype(np.float32))

    ds = xr.Dataset(
        data_vars=data_vars,
        coords={"time": dates},
    )
    return ds
