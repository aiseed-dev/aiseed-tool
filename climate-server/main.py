"""Climate Server — ERA5 historical climate data collection API.

Separate from grow-server. Collects monthly ERA5 / ERA5-Land data
from Open-Meteo, AWS S3, and CDS API.

Usage:
    cd climate-server
    pip install -r requirements.txt
    python main.py            # → http://localhost:8100/docs
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from database import init_db
from routers import era5

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Climate Server on port %d ...", settings.port)
    await init_db()
    logger.info("Database ready: %s", settings.database_url)
    yield
    logger.info("Shutting down Climate Server.")


app = FastAPI(
    title="Climate Server",
    description="ERA5 気候データ収集API（Open-Meteo / AWS S3 / CDS API）",
    version="0.1.0",
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
    # check optional deps
    deps = {}
    for mod in ("xarray", "cdsapi", "netCDF4"):
        try:
            __import__(mod)
            deps[mod] = True
        except ImportError:
            deps[mod] = False
    return {"status": "ok", "optional_deps": deps}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=True)
