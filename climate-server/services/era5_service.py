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
# 座標は市街地を避け、実際の農地にピンを置いている。
# 大都市は ヒートアイランド の影響で郊外農地と気候が異なるため使えない。
# ユーザーの圃場座標を直接使うのが基本だが、
# 一括取得・比較用にプリセットを提供する。

FARM_PRESETS: dict[str, dict] = {
    # ═══ 北海道 ═══
    "tokachi_plain":    {"lat": 42.88, "lon": 143.35, "name": "十勝平野",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "畑作・酪農の中心。小麦・じゃがいも・ビート"},
    "kamikawa_basin":   {"lat": 43.60, "lon": 142.45, "name": "上川盆地",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "東神楽〜東川の水田地帯"},
    "sorachi_plain":    {"lat": 43.22, "lon": 141.85, "name": "空知平野",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "長沼・栗山の米どころ"},
    "furano_basin":     {"lat": 43.28, "lon": 142.40, "name": "富良野盆地",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "メロン・たまねぎ・野菜"},
    "okhotsk_kitami":   {"lat": 43.80, "lon": 143.90, "name": "オホーツク北見",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "たまねぎ日本一・小麦・ビート"},
    "donan_niseko":     {"lat": 42.87, "lon": 140.70, "name": "道南ニセコ",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "じゃがいも・アスパラ"},
    # ═══ 東北 ═══
    "shonai_plain":     {"lat": 38.95, "lon": 140.00, "name": "庄内平野",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "つや姫・はえぬきの水田地帯"},
    "yokote_basin":     {"lat": 39.28, "lon": 140.48, "name": "横手盆地",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "あきたこまち産地の水田"},
    "tsugaru_plain":    {"lat": 40.85, "lon": 140.40, "name": "津軽平野",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "りんご・にんにく・米"},
    "sendai_plain":     {"lat": 38.20, "lon": 140.95, "name": "仙台平野南部",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "名取・岩沼の水田（仙台市街を避けた南部）"},
    "kitakami_basin":   {"lat": 39.10, "lon": 141.15, "name": "北上盆地",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "岩手の米作・雑穀"},
    # ═══ 関東 ═══
    "sanbu":            {"lat": 35.60, "lon": 140.40, "name": "山武郡",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "有機農業が盛んな地域"},
    "fukaya":           {"lat": 36.20, "lon": 139.28, "name": "深谷",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "深谷ねぎ・ブロッコリーの畑作地帯"},
    "inashiki":         {"lat": 36.00, "lon": 140.25, "name": "稲敷",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "茨城県南部の水田地帯"},
    "nasu_highland":    {"lat": 36.97, "lon": 140.05, "name": "那須高原",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "酪農・高原野菜"},
    "tatebayashi":      {"lat": 36.25, "lon": 139.68, "name": "館林",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "群馬の野菜産地（きゅうり・なす）"},
    # ═══ 甲信越・北陸 ═══
    "echigo_uonuma":    {"lat": 37.05, "lon": 138.95, "name": "魚沼",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "コシヒカリ最高産地の水田"},
    "saku_highland":    {"lat": 36.28, "lon": 138.50, "name": "佐久高原",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "高原野菜レタス・ブロッコリー"},
    "toyama_plain":     {"lat": 36.70, "lon": 137.10, "name": "富山平野",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "コシヒカリ水田・チューリップ"},
    "yamanashi_enzan":  {"lat": 35.70, "lon": 138.73, "name": "山梨塩山",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "ぶどう・もも果樹園"},
    # ═══ 東海 ═══
    "makinohara":       {"lat": 34.73, "lon": 138.23, "name": "牧之原台地",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "茶の一大産地"},
    "tahara":           {"lat": 34.65, "lon": 137.17, "name": "田原",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "農業産出額日本一（キャベツ・菊）"},
    # ═══ 近畿 ═══
    "yamato_highland":  {"lat": 34.51, "lon": 135.83, "name": "大和高原",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "大和野菜の産地"},
    "tanba":            {"lat": 35.10, "lon": 135.10, "name": "丹波",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "丹波黒大豆・丹波栗"},
    "arida":            {"lat": 34.08, "lon": 135.13, "name": "有田",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "和歌山みかん産地"},
    # ═══ 中国・四国 ═══
    "kibichuo":         {"lat": 34.83, "lon": 133.77, "name": "吉備中央",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "ぶどう・もも果樹園"},
    "nankoku":          {"lat": 33.57, "lon": 133.63, "name": "南国",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "ナス・ピーマンなどハウス園芸"},
    "hokuei":           {"lat": 35.48, "lon": 133.82, "name": "北栄",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "鳥取すいか・長芋・らっきょう"},
    "sanuki":           {"lat": 34.25, "lon": 133.85, "name": "讃岐平野",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "讃岐うどん用小麦・レタス"},
    # ═══ 九州 ═══
    "aso_highland":     {"lat": 32.95, "lon": 131.05, "name": "阿蘇高原",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "高原野菜・酪農"},
    "saito":            {"lat": 32.10, "lon": 131.40, "name": "西都",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "ピーマン・マンゴー"},
    "saga_shiroishi":   {"lat": 33.18, "lon": 130.30, "name": "佐賀白石",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "佐賀平野の穀倉地帯"},
    "chiran":           {"lat": 31.38, "lon": 130.45, "name": "知覧",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "知覧茶・さつまいも"},
    # ═══ 沖縄 ═══
    "nago":             {"lat": 26.59, "lon": 127.97, "name": "名護",
                         "tz": "Asia/Tokyo", "region": "japan",
                         "note": "ゴーヤー・サトウキビ・パイナップル"},
    # ═══ イタリア（伝統野菜産地） ═══
    "campania_agro":    {"lat": 40.68, "lon": 14.98, "name": "カンパーニャ アグロ・ノチェリーノ",
                         "tz": "Europe/Rome", "region": "italy",
                         "note": "サンマルツァーノトマトDOP産地"},
    "puglia_foggia":    {"lat": 41.46, "lon": 15.54, "name": "プーリア フォッジャ平野",
                         "tz": "Europe/Rome", "region": "italy",
                         "note": "イタリア最大の穀倉地帯・トマト"},
    "sicilia_ragusa":   {"lat": 36.93, "lon": 14.73, "name": "シチリア ラグーザ",
                         "tz": "Europe/Rome", "region": "italy",
                         "note": "ミニトマト・ナス・ズッキーニ"},
    "toscana_maremma":  {"lat": 42.76, "lon": 11.11, "name": "トスカーナ マレンマ",
                         "tz": "Europe/Rome", "region": "italy",
                         "note": "有機農業先進地域"},
    # ═══ フランス ═══
    "beauce":           {"lat": 48.10, "lon": 1.50, "name": "ボース平野",
                         "tz": "Europe/Paris", "region": "france",
                         "note": "フランスの穀倉地帯（小麦・菜種）"},
    "provence":         {"lat": 43.80, "lon": 5.05, "name": "プロヴァンス",
                         "tz": "Europe/Paris", "region": "france",
                         "note": "ラベンダー・ハーブ・野菜"},
    "loire_valley":     {"lat": 47.35, "lon": 0.70, "name": "ロワール渓谷",
                         "tz": "Europe/Paris", "region": "france",
                         "note": "ワイン・野菜・果樹"},
    # ═══ アメリカ ═══
    "central_valley_ca": {"lat": 36.60, "lon": -119.80, "name": "セントラルバレー（CA）",
                          "tz": "America/Los_Angeles", "region": "usa",
                          "note": "米国最大の農業地帯（果物・野菜・ナッツ）"},
    "iowa_corn":        {"lat": 42.00, "lon": -93.50, "name": "アイオワ コーンベルト",
                         "tz": "America/Chicago", "region": "usa",
                         "note": "とうもろこし・大豆"},
    # ═══ 東南アジア ═══
    "chiang_mai":       {"lat": 18.85, "lon": 98.90, "name": "チェンマイ郊外",
                         "tz": "Asia/Bangkok", "region": "southeast_asia",
                         "note": "タイ北部の米・ロンガン農園"},
    "mekong_delta":     {"lat": 10.05, "lon": 105.80, "name": "メコンデルタ",
                         "tz": "Asia/Ho_Chi_Minh", "region": "southeast_asia",
                         "note": "ベトナムの米作地帯"},
    # ═══ オーストラリア ═══
    "murray_darling":   {"lat": -35.10, "lon": 145.90, "name": "マレー・ダーリング",
                         "tz": "Australia/Sydney", "region": "australia",
                         "note": "穀物・牧畜・灌漑農業"},
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
