"""AgERA5 daily climate data via Google Earth Engine.

Agrometeorological indicators from 1979 to present (0.1° ≈ 11 km).
Pre-aggregated daily values with local-timezone min/max — no forecast-hour
handling needed.  Bias-corrected against ECMWF HRES.

GEE collection: projects/climate-engine-pro/assets/ce-ag-era5-v2/daily

Variables mapped to our standard names (same as Open-Meteo source):
    temp_max, temp_min, temp_mean, precipitation,
    shortwave_radiation, wind_speed_max, humidity_mean, ...
"""

import logging
from datetime import datetime, timedelta

import ee
import numpy as np
import pandas as pd
import xarray as xr

logger = logging.getLogger(__name__)

# ── GEE initialisation ──────────────────────────────────────────────

_ee_initialised = False


def _ensure_ee():
    """Lazy-initialise Earth Engine (uses default credentials)."""
    global _ee_initialised
    if _ee_initialised:
        return
    try:
        ee.Initialize(opt_url="https://earthengine.googleapis.com")
    except Exception:
        # ADC / service-account fallback
        ee.Authenticate(auth_mode="appdefault")
        ee.Initialize()
    _ee_initialised = True
    logger.info("Google Earth Engine initialised")


# ── Band mapping ─────────────────────────────────────────────────────

AGERA5_COLLECTION = "projects/climate-engine-pro/assets/ce-ag-era5-v2/daily"

# AgERA5 band name → (our NetCDF name, unit conversion)
# Conversion: "K_to_C" = subtract 273.15, "J_to_MJ" = divide by 1e6,
#              "none" = pass-through
_BAND_MAP: list[tuple[str, str, str]] = [
    ("Temperature_Air_2m_Max_24h",    "temp_max",            "K_to_C"),
    ("Temperature_Air_2m_Min_24h",    "temp_min",            "K_to_C"),
    ("Temperature_Air_2m_Mean_24h",   "temp_mean",           "K_to_C"),
    ("Precipitation_Flux",            "precipitation",       "none"),     # mm/day
    ("Solar_Radiation_Flux",          "shortwave_radiation",  "J_to_MJ"), # J/m² → MJ/m²
    ("Wind_Speed_10m_Mean",           "wind_speed_mean",     "none"),     # m/s
    ("Vapour_Pressure_Mean",          "vapour_pressure",     "none"),     # hPa
    ("Cloud_Cover_Mean",              "cloud_cover",         "none"),     # fraction
    ("Snow_Thickness_Mean",           "snow_depth",          "none"),     # m
    ("Relative_Humidity_2m_06h",      "humidity_06h",        "none"),     # %
    ("Relative_Humidity_2m_09h",      "humidity_09h",        "none"),
    ("Relative_Humidity_2m_12h",      "humidity_12h",        "none"),
    ("Relative_Humidity_2m_15h",      "humidity_15h",        "none"),
    ("Relative_Humidity_2m_18h",      "humidity_18h",        "none"),
]

# Bands we actually request from GEE (source names)
_GEE_BANDS = [b[0] for b in _BAND_MAP]


# ── Core fetch function ──────────────────────────────────────────────

def fetch_daily_agera5(
    lat: float,
    lon: float,
    date_start: str,
    date_end: str,
) -> xr.Dataset:
    """Fetch daily AgERA5 for a single point via GEE.

    Args:
        lat, lon: Location coordinates.
        date_start: "YYYY-MM-DD"
        date_end:   "YYYY-MM-DD" (inclusive)

    Returns:
        xr.Dataset with dim=(time,) and daily climate variables.
    """
    _ensure_ee()

    # GEE filterDate end is exclusive — add 1 day
    end_exclusive = (
        datetime.strptime(date_end, "%Y-%m-%d") + timedelta(days=1)
    ).strftime("%Y-%m-%d")

    point = ee.Geometry.Point([lon, lat])

    col = (
        ee.ImageCollection(AGERA5_COLLECTION)
        .filterDate(date_start, end_exclusive)
        .select(_GEE_BANDS)
    )

    def _extract(image):
        vals = image.reduceRegion(
            reducer=ee.Reducer.first(),
            geometry=point,
            scale=11000,  # ~0.1°
        )
        return ee.Feature(None, vals).set(
            "date", image.date().format("YYYY-MM-dd")
        )

    fc = col.map(_extract)

    # getInfo — blocks until complete; fine for point extraction
    features = fc.getInfo().get("features", [])

    if not features:
        raise ValueError(
            f"AgERA5: no data for ({lat}, {lon}) "
            f"between {date_start} and {date_end}"
        )

    return _features_to_dataset(features, lat, lon)


def _features_to_dataset(
    features: list[dict], lat: float, lon: float,
) -> xr.Dataset:
    """Convert GEE FeatureCollection JSON → xarray.Dataset."""
    rows: list[dict] = []
    for f in features:
        props = f.get("properties", {})
        date_str = props.pop("date", None)
        if not date_str:
            continue
        row = {"date": date_str}
        for gee_band, nc_name, conv in _BAND_MAP:
            val = props.get(gee_band)
            if val is None:
                row[nc_name] = np.nan
                continue
            if conv == "K_to_C":
                val = val - 273.15
            elif conv == "J_to_MJ":
                val = val / 1e6
            row[nc_name] = float(val)
        rows.append(row)

    df = pd.DataFrame(rows)
    df["date"] = pd.to_datetime(df["date"])
    df = df.sort_values("date").set_index("date")

    # Compute daily mean humidity from the 5 fixed-hour readings
    h_cols = [c for c in df.columns if c.startswith("humidity_") and c[-1] == "h"]
    if h_cols:
        df["humidity_mean"] = df[h_cols].mean(axis=1)

    # Build xarray Dataset
    data_vars = {}
    for col in df.columns:
        data_vars[col] = (["time"], df[col].values.astype(np.float32))

    ds = xr.Dataset(
        data_vars=data_vars,
        coords={"time": df.index.values},
    )
    ds.attrs["source"] = "agera5_gee"
    ds.attrs["dataset"] = "AgERA5 v2"
    ds.attrs["resolution_deg"] = 0.1
    ds.attrs["lat"] = lat
    ds.attrs["lon"] = lon
    return ds


# ── Chunked fetch (GEE has 5000-element limit) ──────────────────────

MAX_DAYS_PER_REQUEST = 365


def fetch_daily_agera5_chunked(
    lat: float,
    lon: float,
    date_start: str,
    date_end: str,
) -> xr.Dataset:
    """Fetch AgERA5 in yearly chunks to avoid GEE limits."""
    start = datetime.strptime(date_start, "%Y-%m-%d")
    end = datetime.strptime(date_end, "%Y-%m-%d")

    datasets = []
    chunk_start = start

    while chunk_start <= end:
        chunk_end = min(
            chunk_start + timedelta(days=MAX_DAYS_PER_REQUEST - 1), end
        )
        logger.info(
            "AgERA5 fetch: (%s, %s) %s → %s",
            lat, lon,
            chunk_start.strftime("%Y-%m-%d"),
            chunk_end.strftime("%Y-%m-%d"),
        )
        ds = fetch_daily_agera5(
            lat, lon,
            chunk_start.strftime("%Y-%m-%d"),
            chunk_end.strftime("%Y-%m-%d"),
        )
        datasets.append(ds)
        chunk_start = chunk_end + timedelta(days=1)

    if len(datasets) == 1:
        return datasets[0]
    return xr.concat(datasets, dim="time").sortby("time")
