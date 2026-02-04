"""Grow Desktop Server

Cloudflare Workers 版と同じ API 仕様の FastAPI サーバー。
デスクトップ版 Flutter アプリ用のローカルバックエンド。
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .identify import router as identify_router
from .photos import router as photos_router
from .sync import router as sync_router

app = FastAPI(title="Grow Desktop Server", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(identify_router)
app.include_router(photos_router)
app.include_router(sync_router)


@app.get("/")
@app.get("/health")
async def health():
    return {"status": "ok", "version": "0.1.0"}
