"""AI チャット — Claude Agent SDK 経由（Max 定額プラン対応）

サーバー上の Claude Code（claude login 済み）を利用し、
Max サブスクの定額枠で AI チャットを提供する。
スマホ側に API キーは不要。
"""

import json
import logging
from collections.abc import AsyncGenerator

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from services.auth_service import require_feature

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


class ChatMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    system: str | None = None
    max_tokens: int = 4096
    stream: bool = True


def _build_prompt(req: ChatRequest) -> str:
    """会話履歴を Agent SDK 用の単一プロンプトに変換する。"""
    parts: list[str] = []

    if req.system:
        parts.append(req.system)

    for msg in req.messages:
        if msg.role == "user":
            parts.append(f"User: {msg.content}")
        elif msg.role == "assistant":
            parts.append(f"Assistant: {msg.content}")

    return "\n\n".join(parts)


# ── SDK 呼び出し（変更時はここだけ修正） ──


async def _query_sdk(prompt: str, max_tokens: int) -> AsyncGenerator[str, None]:
    """Claude Agent SDK を呼び出し、テキストチャンクを yield する。

    SDK のバージョンアップで API が変わった場合はこの関数だけ修正する。
    """
    from claude_agent_sdk import (
        AssistantMessage,
        ClaudeAgentOptions,
        TextBlock,
        query,
    )

    options = ClaudeAgentOptions(
        allowed_tools=[],
        permission_mode="bypassPermissions",
        max_tokens=max_tokens,
    )

    async for message in query(prompt=prompt, options=options):
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock):
                    yield block.text


# ── エンドポイント ──


@router.post("/chat")
async def chat(req: ChatRequest, user=Depends(require_feature("ai"))):
    """Claude Agent SDK 経由でチャット。Max 定額プランで従量課金なし。"""
    try:
        import claude_agent_sdk  # noqa: F401
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="claude-agent-sdk is not installed. Run: pip install claude-agent-sdk",
        )

    prompt = _build_prompt(req)

    if not req.stream:
        try:
            parts: list[str] = []
            async for text in _query_sdk(prompt, req.max_tokens):
                parts.append(text)
            return {
                "content": [{"type": "text", "text": "".join(parts)}],
                "role": "assistant",
            }
        except Exception as e:
            logger.error("Agent SDK error: %s", e)
            raise HTTPException(status_code=500, detail=str(e))

    async def sse_stream():
        try:
            async for text in _query_sdk(prompt, req.max_tokens):
                event = {
                    "type": "content_block_delta",
                    "delta": {"type": "text_delta", "text": text},
                }
                yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as e:
            logger.error("Agent SDK stream error: %s", e)
            yield f'data: {json.dumps({"type":"error","error":{"message":str(e)}})}\n\n'

    return StreamingResponse(
        sse_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
