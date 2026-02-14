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

# ── World locations (世界時計 + 栽培分析) ──────────────────────────────

WORLD_LOCATIONS: dict[str, dict] = {
    # Japan
    "tokyo":    {"lat": 35.68, "lon": 139.77, "name": "東京",         "tz": "Asia/Tokyo"},
    "osaka":    {"lat": 34.69, "lon": 135.50, "name": "大阪",         "tz": "Asia/Tokyo"},
    "sapporo":  {"lat": 43.06, "lon": 141.35, "name": "札幌",         "tz": "Asia/Tokyo"},
    "naha":     {"lat": 26.33, "lon": 127.80, "name": "那覇",         "tz": "Asia/Tokyo"},
    # Italy — wine & traditional vegetables
    "roma":     {"lat": 41.90, "lon": 12.50,  "name": "ローマ",       "tz": "Europe/Rome"},
    "milano":   {"lat": 45.46, "lon": 9.19,   "name": "ミラノ",       "tz": "Europe/Rome"},
    "napoli":   {"lat": 40.85, "lon": 14.27,  "name": "ナポリ",       "tz": "Europe/Rome"},
    "firenze":  {"lat": 43.77, "lon": 11.25,  "name": "フィレンツェ", "tz": "Europe/Rome"},
    "sicilia":  {"lat": 37.50, "lon": 14.00,  "name": "シチリア",     "tz": "Europe/Rome"},
    "chianti":  {"lat": 43.47, "lon": 11.25,  "name": "キャンティ",   "tz": "Europe/Rome"},
    # France — wine regions
    "paris":      {"lat": 48.86, "lon": 2.35,   "name": "パリ",           "tz": "Europe/Paris"},
    "bordeaux":   {"lat": 44.84, "lon": -0.58,  "name": "ボルドー",       "tz": "Europe/Paris"},
    "bourgogne":  {"lat": 47.04, "lon": 4.84,   "name": "ブルゴーニュ",   "tz": "Europe/Paris"},
    "champagne":  {"lat": 49.04, "lon": 3.95,   "name": "シャンパーニュ", "tz": "Europe/Paris"},
    # USA
    "new_york":      {"lat": 40.71, "lon": -74.01,  "name": "ニューヨーク",     "tz": "America/New_York"},
    "napa_valley":   {"lat": 38.50, "lon": -122.27, "name": "ナパバレー",       "tz": "America/Los_Angeles"},
    "san_francisco": {"lat": 37.77, "lon": -122.42, "name": "サンフランシスコ", "tz": "America/Los_Angeles"},
    # Other wine regions & world cities
    "london":    {"lat": 51.51, "lon": -0.13,  "name": "ロンドン",       "tz": "Europe/London"},
    "mendoza":   {"lat": -32.89, "lon": -68.83, "name": "メンドーサ",    "tz": "America/Argentina/Buenos_Aires"},
    "barossa":   {"lat": -34.56, "lon": 138.95, "name": "バロッサ",      "tz": "Australia/Adelaide"},
    "cape_town": {"lat": -33.93, "lon": 18.42,  "name": "ケープタウン",  "tz": "Africa/Johannesburg"},
    "singapore": {"lat": 1.35,   "lon": 103.82, "name": "シンガポール",  "tz": "Asia/Singapore"},
    "dubai":     {"lat": 25.20,  "lon": 55.27,  "name": "ドバイ",        "tz": "Asia/Dubai"},
    "sydney":    {"lat": -33.87, "lon": 151.21, "name": "シドニー",      "tz": "Australia/Sydney"},
}


def get_location(key: str) -> Optional[dict]:
    return WORLD_LOCATIONS.get(key)


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
