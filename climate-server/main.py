"""Climate Server — 気候・気象データ統合サーバー。

すべての気候・気象データを一元管理する。
- ERA5 / AgERA5: 過去の気候統計（NetCDF）
- Ecowitt GW3000: リアルタイム観測（Parquet）
- AMeDAS: 気象庁観測データ（Parquet）
- ECMWF: 天気予報（Open-Meteo API 経由）
- GDD: 積算温度（Open-Meteo Archive）
- 世界時計（ERA5 S3）

他のサーバーは API 経由でこのサーバーのデータを利用する。

Usage:
    cd climate-server
    pip install -r requirements.txt
    python main.py            # → http://localhost:8100/docs
"""

import asyncio
import logging
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from config import settings
from routers import era5, world_clock, weather, amedas, forecast, gdd

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    data_dir = Path(settings.data_dir)
    data_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Starting Climate Server on port %d ...", settings.port)
    logger.info("Data directory: %s", data_dir.resolve())

    nc_files = list(data_dir.glob("*.nc"))
    pq_dirs = [d for d in data_dir.iterdir() if d.is_dir()]
    logger.info("Stored locations (NetCDF): %d, sub-dirs: %d", len(nc_files), len(pq_dirs))

    # AMeDAS スケジューラー
    scheduler_task = None
    if settings.amedas_stations:
        from services.amedas_scheduler import amedas_scheduler
        station_ids = [s.strip() for s in settings.amedas_stations.split(",") if s.strip()][:3]
        if station_ids:
            scheduler_task = asyncio.create_task(amedas_scheduler(station_ids))
            logger.info("AMeDAS daily scheduler for: %s", station_ids)

    yield

    if scheduler_task:
        scheduler_task.cancel()
    logger.info("Shutting down Climate Server.")


app = FastAPI(
    title="Climate Server",
    description=(
        "気候・気象データ統合API\n\n"
        "**観測データ**\n"
        "- Ecowitt GW3000 リアルタイム観測 (/weather, /data/report)\n"
        "- AMeDAS 気象庁観測 (/amedas)\n\n"
        "**予報**\n"
        "- ECMWF 天気予報 (/forecast)\n\n"
        "**気候統計**\n"
        "- ERA5 / AgERA5 過去データ (/era5)\n"
        "- 積算温度 GDD (/gdd)\n"
        "- 世界時計 (/world-clock)\n\n"
        "ストレージ: NetCDF (ERA5) + Parquet (観測データ)\n"
    ),
    version="0.5.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ルーター登録
app.include_router(weather.router)
app.include_router(amedas.router)
app.include_router(forecast.router)
app.include_router(gdd.router)
app.include_router(era5.router)
app.include_router(world_clock.router)

# 静的ファイル（Ecowitt UI 等）
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


@app.get("/health")
async def health():
    data_dir = Path(settings.data_dir)
    nc_files = list(data_dir.glob("*.nc")) if data_dir.exists() else []
    ecowitt_dir = data_dir / "ecowitt"
    ecowitt_files = list(ecowitt_dir.glob("*.parquet")) if ecowitt_dir.exists() else []
    amedas_dir = data_dir / "amedas"
    amedas_stations = [d.name for d in amedas_dir.iterdir() if d.is_dir()] if amedas_dir.exists() else []

    return {
        "status": "ok",
        "storage": {"netcdf": len(nc_files), "ecowitt_months": len(ecowitt_files), "amedas_stations": amedas_stations},
        "data_dir": str(data_dir.resolve()),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=True)
