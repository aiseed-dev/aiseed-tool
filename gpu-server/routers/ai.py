"""AI チャットプロキシ — Claude API をサーバー経由で呼び出す

スマホ側に API キーを持たせず、サーバーの Anthropic API キーで処理する。
ストリーミング対応。
"""

import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from config import settings
from routers.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"


class ChatMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    system: str | None = None
    model: str | None = None
    max_tokens: int = 4096
    stream: bool = True


@router.post("/chat")
async def chat(req: ChatRequest, user=Depends(get_current_user)):
    """Claude API へのプロキシ。認証済みユーザーのみ使用可。"""
    if not settings.anthropic_api_key:
        raise HTTPException(
            status_code=503,
            detail="Anthropic API key not configured on server",
        )

    model = req.model or settings.ai_model

    body: dict = {
        "model": model,
        "max_tokens": req.max_tokens,
        "messages": [m.model_dump() for m in req.messages],
        "stream": req.stream,
    }
    if req.system:
        body["system"] = req.system

    headers = {
        "x-api-key": settings.anthropic_api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

    if not req.stream:
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(ANTHROPIC_API_URL, json=body, headers=headers)
            if resp.status_code != 200:
                raise HTTPException(status_code=resp.status_code, detail=resp.text)
            return resp.json()

    # Streaming response
    async def stream_proxy():
        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST", ANTHROPIC_API_URL, json=body, headers=headers
            ) as resp:
                if resp.status_code != 200:
                    error_body = await resp.aread()
                    logger.error("Claude API error %d: %s", resp.status_code, error_body)
                    yield f'data: {{"type":"error","error":{{"message":"Claude API {resp.status_code}"}}}}\n\n'
                    return
                async for line in resp.aiter_lines():
                    yield f"{line}\n"

    return StreamingResponse(
        stream_proxy(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
