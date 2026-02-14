"""ERA5 from AWS S3 — for 世界時計 (global weather display).

Source: s3://nsf-ncar-era5 (public, no auth)
  - e5.oper.fc.sfc.minmax/  → 最高・最低気温, 最大風速
  - e5.oper.fc.sfc.accumu/  → 降水量, 日射量

Resolution: 0.25° global, half-monthly files.
Structure: (forecast_initial_time: 30, forecast_hour: 12, lat: 721, lon: 1440)
  - 06 UTC + 18 UTC = 1 day (12h forecast each)

Variables used:
  minmax:
    128_201_mx2t  — Maximum 2m temperature (K)
    128_202_mn2t  — Minimum 2m temperature (K)
  accumu:
    128_142_lsp   — Large-scale precipitation (m, accumulated)
    128_143_cp    — Convective precipitation (m, accumulated)
    128_169_ssrd  — Surface solar radiation downwards (W m⁻² s, accumulated)
"""

import logging
from datetime import datetime

import numpy as np
import s3fs
import xarray as xr

logger = logging.getLogger(__name__)

S3_BUCKET = "nsf-ncar-era5"

# Variable definitions: (s3_subdir, var_code, var_name_in_nc, our_name, aggregation)
S3_VARIABLES = [
    # minmax
    ("e5.oper.fc.sfc.minmax", "128_201_mx2t", "MX2T", "temp_max", "max"),
    ("e5.oper.fc.sfc.minmax", "128_202_mn2t", "MN2T", "temp_min", "min"),
    # accumu
    ("e5.oper.fc.sfc.accumu", "128_142_lsp", "LSP", "lsp", "sum_accum"),
    ("e5.oper.fc.sfc.accumu", "128_143_cp",  "CP",  "cp",  "sum_accum"),
    ("e5.oper.fc.sfc.accumu", "128_169_ssrd", "SSRD", "shortwave_radiation", "sum_accum"),
]


def _s3_path(subdir: str, var_code: str, yyyymm: str, half: int) -> str:
    """Build S3 path for a half-monthly file.

    half=1: days 01-15 (file: YYYYMM0106_YYYYMMorNextMM1606)
    half=2: days 16-end (file: YYYYMM1606_NextYYYYMM0106)
    """
    year = int(yyyymm[:4])
    month = int(yyyymm[4:6])

    if half == 1:
        start = f"{yyyymm}0106"
        end = f"{yyyymm}1606"
    else:
        start = f"{yyyymm}1606"
        # Next month's 01
        if month == 12:
            end = f"{year + 1}010106"
        else:
            end = f"{year}{month + 1:02d}0106"

    return (
        f"s3://{S3_BUCKET}/{subdir}/{yyyymm}/"
        f"{subdir}.{var_code}.ll025sc.{start}_{end}.nc"
    )


def extract_point_from_s3(
    lat: float,
    lon: float,
    date_str: str,
) -> dict:
    """Extract a single day's weather for one point from S3.

    Returns dict with temp_max, temp_min, precipitation, shortwave_radiation.
    Units: temp in °C, precip in mm, radiation in MJ/m².
    """
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    yyyymm = dt.strftime("%Y%m")
    half = 1 if dt.day <= 15 else 2

    # Normalise longitude to 0-360 range (ERA5 uses 0-360)
    lon360 = lon % 360

    fs = s3fs.S3FileSystem(anon=True)
    result = {"date": date_str, "lat": lat, "lon": lon}

    for subdir, var_code, nc_var, our_name, agg in S3_VARIABLES:
        try:
            path = _s3_path(subdir, var_code, yyyymm, half)
            with fs.open(path) as f:
                ds = xr.open_dataset(f, engine="h5netcdf")
                pt = ds.sel(latitude=lat, longitude=lon360, method="nearest")

                # Find the two init times for this date (06 and 18 UTC)
                init_times = pt.forecast_initial_time.values
                day_inits = [
                    t for t in init_times
                    if str(t)[:10] == date_str
                ]

                if not day_inits:
                    result[our_name] = None
                    continue

                if agg == "max":
                    vals = [float(pt[nc_var].sel(forecast_initial_time=t).max().values) for t in day_inits]
                    val = max(vals) - 273.15  # K → °C
                elif agg == "min":
                    vals = [float(pt[nc_var].sel(forecast_initial_time=t).min().values) for t in day_inits]
                    val = min(vals) - 273.15  # K → °C
                elif agg == "sum_accum":
                    # Accumulated: take forecast_hour=12 (12h total) for each init
                    total = 0.0
                    for t in day_inits:
                        v = float(pt[nc_var].sel(forecast_initial_time=t, forecast_hour=12).values)
                        total += v
                    if our_name in ("lsp", "cp"):
                        val = total * 1000  # m → mm
                    elif our_name == "shortwave_radiation":
                        val = total / 1e6   # W m⁻² s → MJ/m²
                    else:
                        val = total
                else:
                    val = None

                result[our_name] = round(val, 2) if val is not None else None
                ds.close()
        except Exception as e:
            logger.warning("S3 extract failed for %s/%s: %s", var_code, date_str, e)
            result[our_name] = None

    # Combine precipitation
    lsp = result.pop("lsp", None)
    cp = result.pop("cp", None)
    if lsp is not None and cp is not None:
        result["precipitation"] = round(lsp + cp, 2)
    elif lsp is not None:
        result["precipitation"] = lsp
    elif cp is not None:
        result["precipitation"] = cp
    else:
        result["precipitation"] = None

    return result


# ── World clock locations ────────────────────────────────────────────
# These ARE major cities — intentionally, for the world clock display.

WORLD_CLOCK_LOCATIONS: dict[str, dict] = {
    # Japan
    "tokyo":     {"lat": 35.68, "lon": 139.77, "name": "東京",         "tz": "Asia/Tokyo"},
    "osaka":     {"lat": 34.69, "lon": 135.50, "name": "大阪",         "tz": "Asia/Tokyo"},
    "sapporo":   {"lat": 43.06, "lon": 141.35, "name": "札幌",         "tz": "Asia/Tokyo"},
    "naha":      {"lat": 26.33, "lon": 127.80, "name": "那覇",         "tz": "Asia/Tokyo"},
    # Italy
    "roma":      {"lat": 41.90, "lon": 12.50,  "name": "ローマ",       "tz": "Europe/Rome"},
    "milano":    {"lat": 45.46, "lon": 9.19,   "name": "ミラノ",       "tz": "Europe/Rome"},
    "napoli":    {"lat": 40.85, "lon": 14.27,  "name": "ナポリ",       "tz": "Europe/Rome"},
    "firenze":   {"lat": 43.77, "lon": 11.25,  "name": "フィレンツェ", "tz": "Europe/Rome"},
    "sicilia":   {"lat": 37.50, "lon": 14.00,  "name": "シチリア",     "tz": "Europe/Rome"},
    # France
    "paris":     {"lat": 48.86, "lon": 2.35,   "name": "パリ",         "tz": "Europe/Paris"},
    "bordeaux":  {"lat": 44.84, "lon": -0.58,  "name": "ボルドー",     "tz": "Europe/Paris"},
    # USA
    "new_york":      {"lat": 40.71, "lon": -74.01,  "name": "ニューヨーク", "tz": "America/New_York"},
    "san_francisco": {"lat": 37.77, "lon": -122.42, "name": "サンフランシスコ", "tz": "America/Los_Angeles"},
    # Other
    "london":    {"lat": 51.51, "lon": -0.13,  "name": "ロンドン",     "tz": "Europe/London"},
    "singapore": {"lat": 1.35,  "lon": 103.82, "name": "シンガポール", "tz": "Asia/Singapore"},
    "sydney":    {"lat": -33.87, "lon": 151.21, "name": "シドニー",    "tz": "Australia/Sydney"},
}
