"""Climate Server — ERA5 historical climate data collection API.

Daily resolution, NetCDF storage (one file per location).
Data source: Open-Meteo Historical API (ERA5 0.25°).

Usage:
    cd climate-server
    pip install -r requirements.txt
    python main.py            # → http://localhost:8100/docs
"""

import logging
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import era5

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
    logger.info("Stored locations: %d", len(nc_files))
    yield
    logger.info("Shutting down Climate Server.")


app = FastAPI(
    title="Climate Server",
    description=(
        "ERA5 気候データ収集API — daily NetCDF\n\n"
        "Data sources:\n"
        "- Open-Meteo Historical API (ERA5 0.25°)\n"
        "- AgERA5 via Google Earth Engine (0.1°, 農業用, 地形補正)\n"
        "- Sentinel-2 vegetation indices (予定)\n"
    ),
    version="0.3.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(era5.router)


@app.get("/health")
async def health():
    data_dir = Path(settings.data_dir)
    nc_files = list(data_dir.glob("*.nc")) if data_dir.exists() else []
    return {
        "status": "ok",
        "storage": "netcdf",
        "data_dir": str(data_dir.resolve()),
        "stored_locations": len(nc_files),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=True)
