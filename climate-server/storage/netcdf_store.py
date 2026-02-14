"""NetCDF storage — one file per location, daily resolution.

File layout:
    data/
        tokyo.nc          # dims: (time,)  coords: time, lat, lon
        bordeaux.nc
        ...

Each .nc contains all daily ERA5 variables for that location.
Append-friendly: new days are merged into the existing file.
"""

import logging
import os
from pathlib import Path

import numpy as np
import pandas as pd
import xarray as xr

from config import settings

logger = logging.getLogger(__name__)

# Variables stored in each NetCDF file (all daily)
CLIMATE_VARS = [
    "temp_mean", "temp_min", "temp_max",
    "precipitation", "rain", "snowfall",
    "wind_speed_max", "wind_gusts_max",
    "shortwave_radiation", "et0",
    "sunshine_hours",
    "humidity_mean", "pressure_mean",
    "soil_temp_0_7cm", "soil_temp_7_28cm",
    "soil_temp_28_100cm", "soil_temp_100_255cm",
    "soil_moisture_0_7cm", "soil_moisture_7_28cm",
    "soil_moisture_28_100cm", "soil_moisture_100_255cm",
]


def _data_dir() -> Path:
    d = Path(settings.data_dir)
    d.mkdir(parents=True, exist_ok=True)
    return d


def _nc_path(location_key: str) -> Path:
    return _data_dir() / f"{location_key}.nc"


def save_daily(location_key: str, lat: float, lon: float, ds_new: xr.Dataset) -> int:
    """Merge daily data into the location's NetCDF file.

    Returns the number of new days added.
    """
    path = _nc_path(location_key)

    # Ensure attrs
    ds_new.attrs["location"] = location_key
    ds_new.attrs["lat"] = lat
    ds_new.attrs["lon"] = lon
    ds_new.attrs["source"] = "open_meteo"
    ds_new.attrs["dataset"] = "era5"
    ds_new.attrs["resolution"] = 0.25

    if path.exists():
        with xr.open_dataset(path) as ds_existing:
            ds_existing.load()
        # Merge: new data overwrites existing for overlapping dates
        ds_merged = ds_new.combine_first(ds_existing)
        new_days = len(ds_merged.time) - len(ds_existing.time)
    else:
        ds_merged = ds_new
        new_days = len(ds_new.time)

    ds_merged = ds_merged.sortby("time")
    ds_merged.to_netcdf(path, mode="w", engine="netcdf4")
    logger.info("Saved %s: %d days total, %d new", location_key, len(ds_merged.time), new_days)
    return new_days


def load(location_key: str) -> xr.Dataset | None:
    """Load the full dataset for a location."""
    path = _nc_path(location_key)
    if not path.exists():
        return None
    ds = xr.open_dataset(path)
    ds.load()
    ds.close()
    return ds


def load_range(
    location_key: str,
    date_start: str | None = None,
    date_end: str | None = None,
    variables: list[str] | None = None,
) -> xr.Dataset | None:
    """Load a time-sliced, variable-selected subset."""
    ds = load(location_key)
    if ds is None:
        return None
    if date_start or date_end:
        ds = ds.sel(time=slice(date_start, date_end))
    if variables:
        valid = [v for v in variables if v in ds.data_vars]
        if valid:
            ds = ds[valid]
    return ds


def summary(location_key: str) -> dict | None:
    """Quick summary: date range, variable count, total days."""
    ds = load(location_key)
    if ds is None:
        return None
    times = pd.DatetimeIndex(ds.time.values)
    return {
        "location": location_key,
        "lat": float(ds.attrs.get("lat", 0)),
        "lon": float(ds.attrs.get("lon", 0)),
        "date_start": str(times.min().date()),
        "date_end": str(times.max().date()),
        "total_days": len(times),
        "variables": list(ds.data_vars),
    }


def list_locations() -> list[str]:
    """List all location keys that have stored data."""
    d = _data_dir()
    return sorted(p.stem for p in d.glob("*.nc"))


def delete(location_key: str) -> bool:
    """Delete a location's NetCDF file."""
    path = _nc_path(location_key)
    if path.exists():
        path.unlink()
        return True
    return False
