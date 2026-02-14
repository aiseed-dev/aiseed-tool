import asyncio
import logging

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from database import init_db
from routers import ai, auth, ocr, vision, weather, amedas, forecast, skillfile, grow, site

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Grow GPU Server...")
    await init_db()
    logger.info("Database initialized.")

    # AMeDAS 定期取得スケジューラー（1日1回）
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
    logger.info("Shutting down Grow GPU Server.")


app = FastAPI(
    title="Grow GPU Server",
    description="ローカルGPUを活用した栽培支援API（OCR・画像分析・ユーザー管理）",
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

app.include_router(ai.router)
app.include_router(auth.router)
app.include_router(ocr.router)
app.include_router(vision.router)
app.include_router(weather.router)
app.include_router(amedas.router)
app.include_router(forecast.router)
app.include_router(skillfile.router)
app.include_router(grow.router)
app.include_router(site.router)


@app.get("/health")
async def health():
    gpu_available = False
    gpu_name = None
    gpu_memory = None
    try:
        import torch

        gpu_available = torch.cuda.is_available()
        gpu_name = torch.cuda.get_device_name(0) if gpu_available else None
        if gpu_available:
            mem = torch.cuda.get_device_properties(0).total_mem
            gpu_memory = f"{mem / (1024**3):.1f} GB"
    except ImportError:
        pass

    return {
        "status": "ok",
        "gpu_available": gpu_available,
        "gpu_name": gpu_name,
        "gpu_memory": gpu_memory,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
    )
