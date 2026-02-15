"""ERA5 climate data endpoints — daily NetCDF storage.

Coordinate-first API: all endpoints accept lat/lon directly.
Each user's location is stored as a separate NetCDF file keyed by coordinates.

Data sources:
  1. Open-Meteo Historical API (0.25°, immediate, no key)
  2. AgERA5 via Google Earth Engine (0.1° ≈ 11 km, agriculture-optimised)
"""

import logging

import numpy as np
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel

from services.era5_service import fetch_daily_open_meteo, FARM_PRESETS
from storage import netcdf_store

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/era5", tags=["era5"])


# ── Helpers ───────────────────────────────────────────────────────────


def _loc_key(lat: float, lon: float) -> str:
    """Derive a storage key from coordinates.  e.g. '35.68_139.77'"""
    return f"{lat:.2f}_{lon:.2f}"


# ── Response models ───────────────────────────────────────────────────


class DailyRecord(BaseModel):
    """Daily climate record — superset of Open-Meteo + AgERA5 variables."""
    date: str
    # Temperature
    temp_mean: float | None = None
    temp_min: float | None = None
    temp_max: float | None = None
    # Precipitation
    precipitation: float | None = None
    rain: float | None = None
    snowfall: float | None = None
    # Wind
    wind_speed_max: float | None = None
    wind_gusts_max: float | None = None
    wind_speed_mean: float | None = None           # AgERA5
    # Radiation
    shortwave_radiation: float | None = None
    et0: float | None = None
    sunshine_hours: float | None = None
    # Humidity / Pressure
    humidity_mean: float | None = None
    pressure_mean: float | None = None
    vapour_pressure: float | None = None           # AgERA5 (hPa)
    cloud_cover: float | None = None               # AgERA5 (fraction)
    # Humidity at fixed local hours (AgERA5)
    humidity_06h: float | None = None
    humidity_09h: float | None = None
    humidity_12h: float | None = None
    humidity_15h: float | None = None
    humidity_18h: float | None = None
    # Snow (AgERA5)
    snow_depth: float | None = None                # m
    # Soil (Open-Meteo)
    soil_temp_0_7cm: float | None = None
    soil_temp_7_28cm: float | None = None
    soil_temp_28_100cm: float | None = None
    soil_temp_100_255cm: float | None = None
    soil_moisture_0_7cm: float | None = None
    soil_moisture_7_28cm: float | None = None
    soil_moisture_28_100cm: float | None = None
    soil_moisture_100_255cm: float | None = None


class ClimateData(BaseModel):
    lat: float
    lon: float
    date_start: str
    date_end: str
    total_days: int
    source: str = ""
    records: list[DailyRecord]


class CollectResult(BaseModel):
    lat: float
    lon: float
    date_start: str
    date_end: str
    source: str
    status: str  # ok / error
    new_days: int = 0
    message: str = ""


class LocationSummary(BaseModel):
    key: str
    lat: float
    lon: float
    date_start: str
    date_end: str
    total_days: int
    variables: list[str]


def _ds_to_records(ds) -> list[DailyRecord]:
    """Convert xarray Dataset to list of DailyRecord."""
    records = []
    dates = ds.time.values
    for i, t in enumerate(dates):
        date_str = str(np.datetime_as_string(t, unit="D"))
        row = {"date": date_str}
        for var in ds.data_vars:
            val = ds[var].values[i]
            if np.isnan(val):
                row[var] = None
            else:
                row[var] = round(float(val), 2)
        records.append(DailyRecord(**row))
    return records


# ── Endpoints ─────────────────────────────────────────────────────────


class FarmPreset(BaseModel):
    key: str
    name: str
    lat: float
    lon: float
    tz: str
    region: str = ""
    note: str = ""


@router.get("/presets", response_model=list[FarmPreset])
async def get_presets():
    """農業地域プリセット一覧。座標は全て農地上（市街地を避けている）。"""
    return [
        FarmPreset(
            key=k, name=v["name"], lat=v["lat"], lon=v["lon"],
            tz=v["tz"], region=v.get("region", ""), note=v.get("note", ""),
        )
        for k, v in FARM_PRESETS.items()
    ]


@router.post("/collect-presets", response_model=list[CollectResult])
async def collect_presets(
    date_start: str = Query(..., description="開始日 YYYY-MM-DD"),
    date_end: str = Query(..., description="終了日 YYYY-MM-DD"),
    region: str = Query("japan", description="japan / italy / france / usa / southeast_asia / australia / all"),
    source: str = Query("open_meteo", description="open_meteo / agera5"),
):
    """プリセット農業地域を一括収集。

    例: POST /era5/collect-presets?date_start=2023-01-01&date_end=2023-12-31&region=japan
    """
    if region == "all":
        targets = FARM_PRESETS
    else:
        targets = {k: v for k, v in FARM_PRESETS.items() if v.get("region") == region}
    if not targets:
        regions = sorted(set(v.get("region", "") for v in FARM_PRESETS.values()))
        raise HTTPException(404, f"地域 '{region}' が見つかりません。候補: {regions}")

    results: list[CollectResult] = []
    for key, loc in targets.items():
        lat, lon = loc["lat"], loc["lon"]
        loc_key = _loc_key(lat, lon)
        try:
            if source == "agera5":
                from services.agera5_gee import fetch_daily_agera5_chunked
                ds = fetch_daily_agera5_chunked(lat, lon, date_start, date_end)
                src_label = "AgERA5 0.1°"
            else:
                ds = await fetch_daily_open_meteo(lat, lon, date_start, date_end)
                src_label = "Open-Meteo 0.25°"

            new_days = netcdf_store.save_daily(loc_key, lat, lon, ds)
            logger.info("%s collected: %s (%s) — %d new days", src_label, key, loc_key, new_days)
            results.append(CollectResult(
                lat=lat, lon=lon,
                date_start=date_start, date_end=date_end,
                source=src_label, status="ok", new_days=new_days,
                message=f"{loc['name']}: {len(ds.time)} days",
            ))
        except Exception as e:
            logger.exception("Collect error for %s", key)
            results.append(CollectResult(
                lat=lat, lon=lon,
                date_start=date_start, date_end=date_end,
                source=source, status="error", message=f"{loc['name']}: {str(e)[:200]}",
            ))

    return results


class GridInfo(BaseModel):
    total_cells: int
    cells: list[dict]  # [{lat, lon, key}]


@router.get("/grid", response_model=GridInfo)
async def get_grid(
    region: str = Query("kanto", description="地域名 (hokkaido/tohoku/kanto/chubu/kinki/chugoku/shikoku/kyushu/okinawa)"),
):
    """指定地域の 0.1° AgERA5 グリッドセル一覧。

    筆ポリゴンがインポート済みなら農地セルのみ、なければ全セル。
    """
    from services.fude_grid import PREFECTURE_BOUNDS, generate_grid_for_region

    bounds = PREFECTURE_BOUNDS.get(region)
    if not bounds:
        raise HTTPException(404, f"地域 '{region}' が見つかりません。候補: {list(PREFECTURE_BOUNDS.keys())}")

    cells = generate_grid_for_region(
        bounds["lat_min"], bounds["lat_max"],
        bounds["lon_min"], bounds["lon_max"],
    )
    return GridInfo(
        total_cells=len(cells),
        cells=[{"lat": c[0], "lon": c[1], "key": _loc_key(c[0], c[1])} for c in cells],
    )


@router.post("/collect-grid", response_model=list[CollectResult])
async def collect_grid(
    date_start: str = Query(..., description="開始日 YYYY-MM-DD"),
    date_end: str = Query(..., description="終了日 YYYY-MM-DD"),
    region: str = Query("kanto", description="地域名"),
    source: str = Query("open_meteo", description="open_meteo / agera5"),
    fude_centroids: str = Query(
        None,
        description="筆ポリゴン重心座標 (lat1,lon1;lat2,lon2;...) — 指定時はこれをグリッドにスナップ",
    ),
):
    """0.1°グリッド単位で一括収集。筆ポリゴン指定時は農地セルのみ。

    例: POST /era5/collect-grid?region=kanto&date_start=2023-01-01&date_end=2023-12-31
    """
    from services.fude_grid import (
        PREFECTURE_BOUNDS, generate_grid_for_region,
        centroids_to_grid_cells,
    )

    if fude_centroids:
        # 筆ポリゴン重心からグリッドセルを導出（農地のみ）
        pairs = []
        for pair in fude_centroids.split(";"):
            parts = pair.strip().split(",")
            if len(parts) == 2:
                pairs.append((float(parts[0]), float(parts[1])))
        cells = centroids_to_grid_cells(pairs)
        logger.info("Fude-based grid: %d centroids → %d unique cells", len(pairs), len(cells))
    else:
        # 地域全体のグリッド
        bounds = PREFECTURE_BOUNDS.get(region)
        if not bounds:
            raise HTTPException(404, f"地域 '{region}' が見つかりません")
        cells = generate_grid_for_region(
            bounds["lat_min"], bounds["lat_max"],
            bounds["lon_min"], bounds["lon_max"],
        )
        logger.info("Region grid '%s': %d cells", region, len(cells))

    results: list[CollectResult] = []
    for lat, lon in cells:
        key = _loc_key(lat, lon)
        # Skip if already collected
        if netcdf_store.load(key) is not None:
            continue

        try:
            if source == "agera5":
                from services.agera5_gee import fetch_daily_agera5_chunked
                ds = fetch_daily_agera5_chunked(lat, lon, date_start, date_end)
                src_label = "AgERA5 0.1°"
            else:
                ds = await fetch_daily_open_meteo(lat, lon, date_start, date_end)
                src_label = "Open-Meteo 0.25°"

            new_days = netcdf_store.save_daily(key, lat, lon, ds)
            results.append(CollectResult(
                lat=lat, lon=lon,
                date_start=date_start, date_end=date_end,
                source=src_label, status="ok", new_days=new_days,
            ))
        except Exception as e:
            logger.exception("Grid collect error for %s", key)
            results.append(CollectResult(
                lat=lat, lon=lon,
                date_start=date_start, date_end=date_end,
                source=source, status="error", message=str(e)[:200],
            ))

    return results


@router.post("/collect", response_model=CollectResult)
async def collect(
    lat: float = Query(..., description="緯度", examples=[35.68]),
    lon: float = Query(..., description="経度", examples=[139.77]),
    date_start: str = Query(..., description="開始日 YYYY-MM-DD"),
    date_end: str = Query(..., description="終了日 YYYY-MM-DD"),
    source: str = Query("open_meteo", description="open_meteo / agera5"),
):
    """ユーザーの座標で気候データを収集・保存。

    例: POST /era5/collect?lat=35.68&lon=139.77&date_start=2023-01-01&date_end=2023-12-31
    """
    key = _loc_key(lat, lon)

    try:
        if source == "agera5":
            from services.agera5_gee import fetch_daily_agera5_chunked
            ds = fetch_daily_agera5_chunked(lat, lon, date_start, date_end)
            src_label = "AgERA5 0.1°"
        else:
            ds = await fetch_daily_open_meteo(lat, lon, date_start, date_end)
            src_label = "Open-Meteo 0.25°"

        new_days = netcdf_store.save_daily(key, lat, lon, ds)
        logger.info("%s collected: %s — %d new days", src_label, key, new_days)
        return CollectResult(
            lat=lat, lon=lon,
            date_start=date_start, date_end=date_end,
            source=src_label, status="ok", new_days=new_days,
            message=f"{len(ds.time)} days fetched",
        )
    except Exception as e:
        logger.exception("Collect error for %s", key)
        return CollectResult(
            lat=lat, lon=lon,
            date_start=date_start, date_end=date_end,
            source=source, status="error", message=str(e)[:300],
        )


@router.get("/climate", response_model=ClimateData)
async def query_climate(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    date_start: str = Query(None, description="開始日 YYYY-MM-DD"),
    date_end: str = Query(None, description="終了日 YYYY-MM-DD"),
    variables: str = Query(None, description="カンマ区切り変数名 (例: temp_mean,precipitation)"),
):
    """保存済みの daily データを取得。グラフ描画用。"""
    key = _loc_key(lat, lon)

    var_list = None
    if variables:
        var_list = [v.strip() for v in variables.split(",") if v.strip()]

    ds = netcdf_store.load_range(key, date_start, date_end, var_list)
    if ds is None:
        raise HTTPException(
            404,
            f"({lat}, {lon}) のデータがありません。"
            "先に POST /era5/collect で取得してください",
        )

    if len(ds.time) == 0:
        raise HTTPException(404, "指定期間のデータがありません")

    times = ds.time.values
    return ClimateData(
        lat=lat, lon=lon,
        date_start=str(np.datetime_as_string(times[0], unit="D")),
        date_end=str(np.datetime_as_string(times[-1], unit="D")),
        total_days=len(times),
        source=ds.attrs.get("source", ""),
        records=_ds_to_records(ds),
    )


@router.get("/summary", response_model=list[LocationSummary])
async def collection_summary():
    """保存済み全地点のサマリー。"""
    stored = netcdf_store.list_locations()
    results = []
    for key in stored:
        info = netcdf_store.summary(key)
        if info:
            results.append(LocationSummary(key=key, **info))
    return results


@router.get("/variables")
async def list_variables():
    """利用可能な気象変数一覧。"""
    return {
        "sources": {
            "open_meteo": "Open-Meteo Historical API (ERA5 0.25°, 即時, キー不要)",
            "agera5":     "AgERA5 via Google Earth Engine (0.1°, 農業用, 地形補正)",
        },
        "variables": {
            # Common (both sources)
            "temp_mean":             {"desc": "日平均気温 (°C)",         "sources": ["open_meteo", "agera5"]},
            "temp_min":              {"desc": "日最低気温 (°C)",         "sources": ["open_meteo", "agera5"]},
            "temp_max":              {"desc": "日最高気温 (°C)",         "sources": ["open_meteo", "agera5"]},
            "precipitation":         {"desc": "降水量 (mm/day)",         "sources": ["open_meteo", "agera5"]},
            "shortwave_radiation":   {"desc": "短波放射 (MJ/m²)",        "sources": ["open_meteo", "agera5"]},
            "humidity_mean":         {"desc": "日平均相対湿度 (%)",       "sources": ["open_meteo", "agera5"]},
            # Open-Meteo only
            "rain":                  {"desc": "降雨量 (mm/day)",          "sources": ["open_meteo"]},
            "snowfall":              {"desc": "降雪量 (cm/day)",          "sources": ["open_meteo"]},
            "wind_speed_max":        {"desc": "最大風速 (m/s)",           "sources": ["open_meteo"]},
            "wind_gusts_max":        {"desc": "最大瞬間風速 (m/s)",       "sources": ["open_meteo"]},
            "et0":                   {"desc": "基準蒸発散量 (mm/day)",    "sources": ["open_meteo"]},
            "sunshine_hours":        {"desc": "日照時間 (hours)",         "sources": ["open_meteo"]},
            "pressure_mean":         {"desc": "日平均気圧 (hPa)",         "sources": ["open_meteo"]},
            "soil_temp_0_7cm":       {"desc": "地温 0-7cm (°C)",          "sources": ["open_meteo"]},
            "soil_temp_7_28cm":      {"desc": "地温 7-28cm (°C)",         "sources": ["open_meteo"]},
            "soil_temp_28_100cm":    {"desc": "地温 28-100cm (°C)",       "sources": ["open_meteo"]},
            "soil_temp_100_255cm":   {"desc": "地温 100-255cm (°C)",      "sources": ["open_meteo"]},
            "soil_moisture_0_7cm":   {"desc": "土壌水分 0-7cm (m³/m³)",   "sources": ["open_meteo"]},
            "soil_moisture_7_28cm":  {"desc": "土壌水分 7-28cm (m³/m³)",  "sources": ["open_meteo"]},
            "soil_moisture_28_100cm":  {"desc": "土壌水分 28-100cm (m³/m³)",  "sources": ["open_meteo"]},
            "soil_moisture_100_255cm": {"desc": "土壌水分 100-255cm (m³/m³)", "sources": ["open_meteo"]},
            # AgERA5 only
            "wind_speed_mean":       {"desc": "日平均風速 (m/s)",          "sources": ["agera5"]},
            "vapour_pressure":       {"desc": "蒸気圧 (hPa)",             "sources": ["agera5"]},
            "cloud_cover":           {"desc": "雲量 (fraction)",           "sources": ["agera5"]},
            "snow_depth":            {"desc": "積雪深 (m)",                "sources": ["agera5"]},
            "humidity_06h":          {"desc": "相対湿度 06時 (%)",         "sources": ["agera5"]},
            "humidity_09h":          {"desc": "相対湿度 09時 (%)",         "sources": ["agera5"]},
            "humidity_12h":          {"desc": "相対湿度 12時 (%)",         "sources": ["agera5"]},
            "humidity_15h":          {"desc": "相対湿度 15時 (%)",         "sources": ["agera5"]},
            "humidity_18h":          {"desc": "相対湿度 18時 (%)",         "sources": ["agera5"]},
        },
    }
