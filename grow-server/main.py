import logging

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from database import init_db
from routers import ai, auth, ocr, vision, skillfile, grow, site, fude, qr, consumer, admin

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Grow Server...")
    await init_db()
    logger.info("Database initialized.")

    yield

    logger.info("Shutting down Grow Server.")


app = FastAPI(
    title="Grow Server",
    description="栽培支援API（AI分析・ユーザー管理・サイト生成・消費者プラットフォーム）",
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
app.include_router(skillfile.router)
app.include_router(grow.router)
app.include_router(site.router)
app.include_router(fude.router)
app.include_router(qr.router)
app.include_router(consumer.router)
app.include_router(admin.router)


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
