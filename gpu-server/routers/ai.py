"""AI チャット — Claude Agent SDK 経由（Max 定額プラン対応）

サーバー上の Claude Code（claude login 済み）を利用し、
Max サブスクの定額枠で AI チャットを提供する。
スマホ側に API キーは不要。
"""

import json
import logging

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from routers.auth import get_current_user

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


@router.post("/chat")
async def chat(req: ChatRequest, user=Depends(get_current_user)):
    """Claude Agent SDK 経由でチャット。Max 定額プランで従量課金なし。"""
    try:
        from claude_agent_sdk import (  # noqa: E402
            AssistantMessage,
            ClaudeAgentOptions,
            TextBlock,
            query,
        )
    except ImportError:
        raise HTTPException(
            status_code=503,
            detail="claude-agent-sdk is not installed. Run: pip install claude-agent-sdk",
        )

    prompt = _build_prompt(req)

    options = ClaudeAgentOptions(
        allowed_tools=[],
        permission_mode="bypassPermissions",
        max_tokens=req.max_tokens,
    )

    if not req.stream:
        try:
            result_parts: list[str] = []
            async for message in query(prompt=prompt, options=options):
                if isinstance(message, AssistantMessage):
                    for block in message.content:
                        if isinstance(block, TextBlock):
                            result_parts.append(block.text)
            return {
                "content": [{"type": "text", "text": "".join(result_parts)}],
                "role": "assistant",
            }
        except Exception as e:
            logger.error("Agent SDK error: %s", e)
            raise HTTPException(status_code=500, detail=str(e))

    # ── Streaming — Claude SSE 互換フォーマット ──
    async def stream_response():
        try:
            async for message in query(prompt=prompt, options=options):
                if isinstance(message, AssistantMessage):
                    for block in message.content:
                        if isinstance(block, TextBlock):
                            event = {
                                "type": "content_block_delta",
                                "delta": {
                                    "type": "text_delta",
                                    "text": block.text,
                                },
                            }
                            yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as e:
            logger.error("Agent SDK stream error: %s", e)
            error_event = {
                "type": "error",
                "error": {"message": str(e)},
            }
            yield f"data: {json.dumps(error_event, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        stream_response(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
