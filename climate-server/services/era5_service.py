"""ERA5 climate data fetcher — multi-source monthly aggregation.

Source 1: Open-Meteo Historical API (immediate, no key)
  - ERA5 + ERA5-Land blend, 0.25°
  - https://archive-api.open-meteo.com/v1/archive

Source 2: AWS S3 nsf-ncar-era5 bucket (bulk, no key)
  - ERA5 0.25°, NetCDF
  - s3://nsf-ncar-era5/{year}/{month}/data/{variable}.nc
  - Requires: xarray h5netcdf s3fs

Source 3: CDS API (account required)
  - ERA5-Land monthly means, 0.1°
  - Requires: cdsapi + ~/.cdsapirc
"""

import logging
import calendar
import math
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from typing import Optional

import httpx

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
# Source 1: Open-Meteo Historical API
# ═══════════════════════════════════════════════════════════════════════

OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"

_DAILY_VARS = [
    "temperature_2m_max", "temperature_2m_min", "temperature_2m_mean",
    "precipitation_sum", "rain_sum", "snowfall_sum",
    "wind_speed_10m_max", "wind_gusts_10m_max",
    "shortwave_radiation_sum", "et0_fao_evapotranspiration",
    "sunshine_duration",
]

_HOURLY_VARS = [
    "relative_humidity_2m", "surface_pressure",
    "soil_temperature_0_to_7cm", "soil_temperature_7_to_28cm",
    "soil_temperature_28_to_100cm", "soil_temperature_100_to_255cm",
    "soil_moisture_0_to_7cm", "soil_moisture_7_to_28cm",
    "soil_moisture_28_to_100cm", "soil_moisture_100_to_255cm",
]


async def fetch_era5_open_meteo(
    lat: float, lon: float, year: int, month: int,
) -> dict:
    """Fetch ERA5 monthly data via Open-Meteo (no key, immediate)."""
    _, last_day = calendar.monthrange(year, month)
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": f"{year:04d}-{month:02d}-01",
        "end_date": f"{year:04d}-{month:02d}-{last_day:02d}",
        "daily": ",".join(_DAILY_VARS),
        "hourly": ",".join(_HOURLY_VARS),
        "wind_speed_unit": "ms",
        "timezone": "UTC",
    }
    async with httpx.AsyncClient() as client:
        resp = await client.get(OPEN_METEO_ARCHIVE_URL, params=params, timeout=60)
        resp.raise_for_status()
        raw = resp.json()
    return _aggregate_open_meteo(raw, lat, lon, year, month)


def _aggregate_open_meteo(
    raw: dict, lat: float, lon: float, year: int, month: int,
) -> dict:
    daily = raw.get("daily", {})
    hourly = raw.get("hourly", {})

    def _vals(src: dict, key: str) -> list[float]:
        return [v for v in (src.get(key) or []) if v is not None]

    def _avg(v: list[float]) -> Optional[float]:
        return round(sum(v) / len(v), 2) if v else None

    def _total(v: list[float]) -> Optional[float]:
        return round(sum(v), 2) if v else None

    d = _vals  # shorthand
    temp_means = d(daily, "temperature_2m_mean")
    temp_mins  = d(daily, "temperature_2m_min")
    temp_maxs  = d(daily, "temperature_2m_max")
    precip     = d(daily, "precipitation_sum")
    rain       = d(daily, "rain_sum")
    snow       = d(daily, "snowfall_sum")
    wind_max   = d(daily, "wind_speed_10m_max")
    gusts_max  = d(daily, "wind_gusts_10m_max")
    radiation  = d(daily, "shortwave_radiation_sum")
    et0        = d(daily, "et0_fao_evapotranspiration")
    sun_secs   = d(daily, "sunshine_duration")

    humidity    = d(hourly, "relative_humidity_2m")
    pressure_pa = d(hourly, "surface_pressure")

    return {
        "lat": round(lat, 2), "lon": round(lon, 2),
        "year": year, "month": month,
        "source": "open_meteo", "dataset": "era5", "resolution": 0.25,
        "fetched_at": datetime.now(timezone.utc),
        "temp_mean": _avg(temp_means),
        "temp_min":  round(min(temp_mins), 1) if temp_mins else None,
        "temp_max":  round(max(temp_maxs), 1) if temp_maxs else None,
        "precipitation_total": _total(precip),
        "rain_total":     _total(rain),
        "snowfall_total": _total(snow),
        "wind_speed_mean": _avg(wind_max),
        "wind_speed_max":  round(max(wind_max), 1) if wind_max else None,
        "wind_gusts_max":  round(max(gusts_max), 1) if gusts_max else None,
        "humidity_mean":  _avg(humidity),
        "pressure_mean":  _avg([p / 100.0 for p in pressure_pa]) if pressure_pa else None,
        "sunshine_hours":  round(sum(sun_secs) / 3600.0, 1) if sun_secs else None,
        "solar_radiation": _avg(radiation),
        "et0_total": _total(et0),
        "soil_temp_0_7cm":      _avg(d(hourly, "soil_temperature_0_to_7cm")),
        "soil_temp_7_28cm":     _avg(d(hourly, "soil_temperature_7_to_28cm")),
        "soil_temp_28_100cm":   _avg(d(hourly, "soil_temperature_28_to_100cm")),
        "soil_temp_100_255cm":  _avg(d(hourly, "soil_temperature_100_to_255cm")),
        "soil_moisture_0_7cm":      _avg(d(hourly, "soil_moisture_0_to_7cm")),
        "soil_moisture_7_28cm":     _avg(d(hourly, "soil_moisture_7_to_28cm")),
        "soil_moisture_28_100cm":   _avg(d(hourly, "soil_moisture_28_to_100cm")),
        "soil_moisture_100_255cm":  _avg(d(hourly, "soil_moisture_100_to_255cm")),
    }


# ═══════════════════════════════════════════════════════════════════════
# Source 2: AWS S3 nsf-ncar-era5
# ═══════════════════════════════════════════════════════════════════════

AWS_ERA5_BUCKET = "nsf-ncar-era5"
AWS_ERA5_REGION = "us-west-2"
AWS_ERA5_BASE = f"https://{AWS_ERA5_BUCKET}.s3.{AWS_ERA5_REGION}.amazonaws.com"

AWS_ERA5_VAR_MAP = {
    "air_temperature_at_2_metres":                   ("temp_mean", "K_to_C"),
    "air_temperature_at_2_metres_1hour_Maximum":     ("temp_max",  "K_to_C"),
    "air_temperature_at_2_metres_1hour_Minimum":     ("temp_min",  "K_to_C"),
    "precipitation_amount_1hour_Accumulation":       ("precipitation_total", None),
    "eastward_wind_at_10_metres":                    ("_u_wind", None),
    "northward_wind_at_10_metres":                   ("_v_wind", None),
    "surface_air_pressure":                          ("pressure_mean", "Pa_to_hPa"),
}


async def list_era5_aws_variables(year: int, month: int) -> list[str]:
    """List available NetCDF variables on S3 for a given month."""
    prefix = f"{year:04d}/{month:02d}/data/"
    url = f"{AWS_ERA5_BASE}?list-type=2&prefix={prefix}&delimiter=/"
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, timeout=30)
        resp.raise_for_status()
    ns = {"s3": "http://s3.amazonaws.com/doc/2006-03-01/"}
    root = ET.fromstring(resp.text)
    return [
        c.text.split("/")[-1].replace(".nc", "")
        for c in root.findall(".//s3:Contents/s3:Key", ns)
        if c.text and c.text.endswith(".nc")
    ]


async def fetch_era5_aws_metadata(year: int, month: int) -> dict:
    """Check available files on AWS S3 without downloading."""
    variables = await list_era5_aws_variables(year, month)
    return {
        "bucket": AWS_ERA5_BUCKET,
        "region": AWS_ERA5_REGION,
        "year": year, "month": month,
        "variables": variables,
        "variable_count": len(variables),
        "download_urls": {
            v: f"{AWS_ERA5_BASE}/{year:04d}/{month:02d}/data/{v}.nc"
            for v in variables
        },
    }


async def fetch_era5_aws_point(
    lat: float, lon: float, year: int, month: int,
) -> Optional[dict]:
    """Extract point data from AWS S3 NetCDF. Requires xarray+s3fs."""
    try:
        import xarray as xr
        import numpy as np
    except ImportError:
        logger.warning("xarray not installed — pip install xarray h5netcdf s3fs")
        return None

    result: dict = {
        "lat": round(lat, 2), "lon": round(lon, 2),
        "year": year, "month": month,
        "source": "aws_s3", "dataset": "era5", "resolution": 0.25,
        "fetched_at": datetime.now(timezone.utc),
    }

    for s3_var, (field, conv) in AWS_ERA5_VAR_MAP.items():
        path = f"s3://{AWS_ERA5_BUCKET}/{year:04d}/{month:02d}/data/{s3_var}.nc"
        try:
            ds = xr.open_dataset(path, engine="h5netcdf")
            pt = ds.sel(latitude=lat, longitude=lon, method="nearest")
            val = float(np.nanmean(pt[list(pt.data_vars)[0]].values))
            ds.close()
            if conv == "K_to_C":
                val -= 273.15
            elif conv == "Pa_to_hPa":
                val /= 100.0
            if field.startswith("_"):
                result[field] = val
            else:
                result[field] = round(val, 2)
        except Exception as e:
            logger.debug("AWS S3 %s: %s", s3_var, e)

    # wind speed from u, v components
    u = result.pop("_u_wind", None)
    v = result.pop("_v_wind", None)
    if u is not None and v is not None:
        result["wind_speed_mean"] = round(math.sqrt(u**2 + v**2), 2)

    return result


# ═══════════════════════════════════════════════════════════════════════
# Source 3: CDS API (ERA5-Land monthly means)
# ═══════════════════════════════════════════════════════════════════════

CDS_DATASET = "reanalysis-era5-land-monthly-means"
CDS_VAR_MAP = {
    "2m_temperature":                       ("temp_mean",           "K_to_C"),
    "total_precipitation":                  ("precipitation_total", "m_to_mm_monthly"),
    "10m_u_component_of_wind":              ("_u_wind",             None),
    "10m_v_component_of_wind":              ("_v_wind",             None),
    "surface_pressure":                     ("pressure_mean",       "Pa_to_hPa"),
    "surface_solar_radiation_downwards":    ("solar_radiation",     "J_to_MJ"),
    "soil_temperature_level_1":             ("soil_temp_0_7cm",     "K_to_C"),
    "soil_temperature_level_2":             ("soil_temp_7_28cm",    "K_to_C"),
    "soil_temperature_level_3":             ("soil_temp_28_100cm",  "K_to_C"),
    "soil_temperature_level_4":             ("soil_temp_100_255cm", "K_to_C"),
    "volumetric_soil_water_layer_1":        ("soil_moisture_0_7cm",     None),
    "volumetric_soil_water_layer_2":        ("soil_moisture_7_28cm",    None),
    "volumetric_soil_water_layer_3":        ("soil_moisture_28_100cm",  None),
    "volumetric_soil_water_layer_4":        ("soil_moisture_100_255cm", None),
    "total_evaporation":                    ("et0_total",           "m_to_mm"),
}


async def fetch_era5_land_cds(
    lat: float, lon: float, year: int, month: int,
    cds_url: str = "", cds_key: str = "",
) -> Optional[dict]:
    """Fetch ERA5-Land monthly mean from Copernicus CDS API.

    Requires: pip install cdsapi xarray netCDF4
    """
    try:
        import cdsapi
    except ImportError:
        logger.warning("cdsapi not installed — pip install cdsapi")
        return None

    area = [round(lat + 0.2, 1), round(lon - 0.2, 1),
            round(lat - 0.2, 1), round(lon + 0.2, 1)]

    import tempfile, os
    tmp_path = tempfile.mktemp(suffix=".nc")

    try:
        kw = {}
        if cds_url and cds_key:
            kw = {"url": cds_url, "key": cds_key}
        c = cdsapi.Client(**kw, quiet=True)
        c.retrieve(CDS_DATASET, {
            "product_type": "monthly_averaged_reanalysis",
            "variable": list(CDS_VAR_MAP.keys()),
            "year": str(year), "month": f"{month:02d}",
            "time": "00:00", "area": area, "format": "netcdf",
        }, tmp_path)
        return _parse_cds(tmp_path, lat, lon, year, month)
    except Exception as e:
        logger.error("CDS API failed: %s", e)
        return None
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def _parse_cds(path: str, lat: float, lon: float, year: int, month: int) -> dict:
    import xarray as xr

    ds = xr.open_dataset(path)
    pt = ds.sel(latitude=lat, longitude=lon, method="nearest")
    _, last_day = calendar.monthrange(year, month)

    result: dict = {
        "lat": round(lat, 2), "lon": round(lon, 2),
        "year": year, "month": month,
        "source": "cds_api", "dataset": "era5_land", "resolution": 0.1,
        "fetched_at": datetime.now(timezone.utc),
    }

    for cds_var, (field, conv) in CDS_VAR_MAP.items():
        try:
            val = None
            for dv in ds.data_vars:
                if cds_var.replace("_", "") in dv.replace("_", "").lower():
                    val = float(pt[dv].values.flatten()[0])
                    break
            if val is None:
                continue
            if conv == "K_to_C":
                val -= 273.15
            elif conv == "Pa_to_hPa":
                val /= 100.0
            elif conv == "m_to_mm":
                val *= 1000.0
            elif conv == "m_to_mm_monthly":
                val *= 1000.0 * last_day
            elif conv == "J_to_MJ":
                val /= 1_000_000.0
            if field.startswith("_"):
                result[field] = val
            else:
                result[field] = round(val, 4)
        except Exception as e:
            logger.debug("CDS parse %s: %s", cds_var, e)

    u = result.pop("_u_wind", None)
    v = result.pop("_v_wind", None)
    if u is not None and v is not None:
        result["wind_speed_mean"] = round(math.sqrt(u**2 + v**2), 2)

    ds.close()
    return result
