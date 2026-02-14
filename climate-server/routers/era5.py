"""ERA5 climate data endpoints — daily NetCDF storage.

Provides historical daily climate data for:
  - 栽培適性分析 (soil temp, moisture, precipitation)
  - 世界時計 weather context (temperature, conditions per city)
  - 長期トレンド分析 (30+ years of daily data)
  - グラフ描画 (time-series ready xarray output)
"""

import numpy as np
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel

from services.era5_service import (
    fetch_daily_open_meteo,
    get_location,
    WORLD_LOCATIONS,
)
from storage import netcdf_store

router = APIRouter(prefix="/era5", tags=["era5"])


# ── Response models ───────────────────────────────────────────────────


class LocationInfo(BaseModel):
    key: str
    name: str
    lat: float
    lon: float
    tz: str


class DailyRecord(BaseModel):
    date: str
    temp_mean: float | None = None
    temp_min: float | None = None
    temp_max: float | None = None
    precipitation: float | None = None
    rain: float | None = None
    snowfall: float | None = None
    wind_speed_max: float | None = None
    wind_gusts_max: float | None = None
    shortwave_radiation: float | None = None
    et0: float | None = None
    sunshine_hours: float | None = None
    humidity_mean: float | None = None
    pressure_mean: float | None = None
    soil_temp_0_7cm: float | None = None
    soil_temp_7_28cm: float | None = None
    soil_temp_28_100cm: float | None = None
    soil_temp_100_255cm: float | None = None
    soil_moisture_0_7cm: float | None = None
    soil_moisture_7_28cm: float | None = None
    soil_moisture_28_100cm: float | None = None
    soil_moisture_100_255cm: float | None = None


class ClimateData(BaseModel):
    location: str
    lat: float
    lon: float
    date_start: str
    date_end: str
    total_days: int
    records: list[DailyRecord]


class CollectResult(BaseModel):
    location: str
    date_start: str
    date_end: str
    status: str  # ok / error
    new_days: int = 0
    message: str = ""


class CollectSummary(BaseModel):
    total: int
    ok: int
    errors: int
    results: list[CollectResult]


class LocationSummary(BaseModel):
    location: str
    lat: float
    lon: float
    date_start: str
    date_end: str
    total_days: int
    variables: list[str]


# ── Helpers ───────────────────────────────────────────────────────────


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


@router.get("/locations", response_model=list[LocationInfo])
async def get_locations():
    """世界時計 + 栽培分析の対象地点一覧。"""
    return [
        LocationInfo(key=k, name=v["name"], lat=v["lat"], lon=v["lon"], tz=v["tz"])
        for k, v in WORLD_LOCATIONS.items()
    ]


@router.post("/collect", response_model=CollectSummary)
async def collect_batch(
    date_start: str = Query(..., description="開始日 YYYY-MM-DD"),
    date_end: str = Query(..., description="終了日 YYYY-MM-DD"),
    locations: str = Query("all", description="カンマ区切り or 'all'"),
):
    """複数地点の一括収集。Open-Meteoからdailyデータを取得しNetCDFに保存。

    例: POST /era5/collect?date_start=2020-01-01&date_end=2024-12-31&locations=tokyo,roma
    """
    if locations == "all":
        targets = list(WORLD_LOCATIONS.items())
    else:
        keys = [k.strip() for k in locations.split(",") if k.strip()]
        targets = []
        for k in keys:
            loc = get_location(k)
            if not loc:
                raise HTTPException(404, f"地点 '{k}' が見つかりません")
            targets.append((k, loc))

    results: list[CollectResult] = []

    for key, loc in targets:
        try:
            ds = await fetch_daily_open_meteo(
                loc["lat"], loc["lon"], date_start, date_end,
            )
            new_days = netcdf_store.save_daily(key, loc["lat"], loc["lon"], ds)
            results.append(CollectResult(
                location=key, date_start=date_start, date_end=date_end,
                status="ok", new_days=new_days,
            ))
        except Exception as e:
            results.append(CollectResult(
                location=key, date_start=date_start, date_end=date_end,
                status="error", message=str(e)[:200],
            ))

    ok = sum(1 for r in results if r.status == "ok")
    err = sum(1 for r in results if r.status == "error")
    return CollectSummary(total=len(results), ok=ok, errors=err, results=results)


@router.get("/climate", response_model=ClimateData)
async def query_climate(
    location: str = Query(..., description="地点キー (例: tokyo, bordeaux)"),
    date_start: str = Query(None, description="開始日 YYYY-MM-DD"),
    date_end: str = Query(None, description="終了日 YYYY-MM-DD"),
    variables: str = Query(None, description="カンマ区切り変数名 (例: temp_mean,precipitation)"),
):
    """保存済みの daily ERA5 データを取得。グラフ描画用。"""
    loc = get_location(location)
    if not loc:
        raise HTTPException(404, f"地点 '{location}' が見つかりません")

    var_list = None
    if variables:
        var_list = [v.strip() for v in variables.split(",") if v.strip()]

    ds = netcdf_store.load_range(location, date_start, date_end, var_list)
    if ds is None:
        raise HTTPException(404, f"'{location}' のデータがありません。先に /era5/collect で取得してください")

    if len(ds.time) == 0:
        raise HTTPException(404, f"指定期間のデータがありません")

    times = ds.time.values
    return ClimateData(
        location=location,
        lat=loc["lat"], lon=loc["lon"],
        date_start=str(np.datetime_as_string(times[0], unit="D")),
        date_end=str(np.datetime_as_string(times[-1], unit="D")),
        total_days=len(times),
        records=_ds_to_records(ds),
    )


@router.get("/summary", response_model=list[LocationSummary])
async def collection_summary():
    """全地点の収集状況サマリー。"""
    stored = netcdf_store.list_locations()
    results = []
    for key in stored:
        info = netcdf_store.summary(key)
        if info:
            results.append(LocationSummary(**info))
    return results


@router.get("/variables")
async def list_variables():
    """利用可能な気象変数一覧。"""
    return {
        "variables": netcdf_store.CLIMATE_VARS,
        "description": {
            "temp_mean": "日平均気温 (°C)",
            "temp_min": "日最低気温 (°C)",
            "temp_max": "日最高気温 (°C)",
            "precipitation": "降水量 (mm/day)",
            "rain": "降雨量 (mm/day)",
            "snowfall": "降雪量 (cm/day)",
            "wind_speed_max": "最大風速 (m/s)",
            "wind_gusts_max": "最大瞬間風速 (m/s)",
            "shortwave_radiation": "短波放射 (MJ/m²)",
            "et0": "基準蒸発散量 (mm/day)",
            "sunshine_hours": "日照時間 (hours)",
            "humidity_mean": "日平均相対湿度 (%)",
            "pressure_mean": "日平均気圧 (hPa)",
            "soil_temp_0_7cm": "地温 0-7cm (°C)",
            "soil_temp_7_28cm": "地温 7-28cm (°C)",
            "soil_temp_28_100cm": "地温 28-100cm (°C)",
            "soil_temp_100_255cm": "地温 100-255cm (°C)",
            "soil_moisture_0_7cm": "土壌水分 0-7cm (m³/m³)",
            "soil_moisture_7_28cm": "土壌水分 7-28cm (m³/m³)",
            "soil_moisture_28_100cm": "土壌水分 28-100cm (m³/m³)",
            "soil_moisture_100_255cm": "土壌水分 100-255cm (m³/m³)",
        },
    }
