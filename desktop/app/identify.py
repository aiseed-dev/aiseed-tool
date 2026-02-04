"""Claude Vision を使った植物同定

POST /identify
  Content-Type: multipart/form-data
  Body: image (file)

Response:
  { "results": [{ "name": "トマト", "confidence": 0.95, "description": "..." }] }
"""

import base64
import json
import re
from dataclasses import dataclass

import anthropic
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File

from .auth import verify_token
from . import config

router = APIRouter()

PROMPT = """この写真に写っている植物を同定してください。

以下のJSON形式で回答してください（説明文は不要、JSONのみ）:
[
  {
    "name": "植物の一般名（日本語）",
    "scientific_name": "学名",
    "confidence": 0.0-1.0の確信度,
    "description": "状態の簡潔な説明（成長段階、健康状態、特徴など）"
  }
]

注意:
- 栽培作物だけでなく、雑草も同定してください
- 複数の植物が写っている場合はすべて列挙してください
- 確信度が低い場合でも候補を返してください
- 植物が写っていない場合は空配列 [] を返してください"""


@dataclass
class IdentifyResult:
    name: str
    confidence: float
    description: str | None = None


def _detect_media_type(content_type: str | None, filename: str | None) -> str:
    if content_type and content_type.startswith("image/"):
        return content_type
    ext = (filename or "").rsplit(".", 1)[-1].lower() if filename else ""
    return {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp",
        "gif": "image/gif",
        "heic": "image/heic",
    }.get(ext, "image/jpeg")


def _extract_json(text: str) -> str:
    # Try markdown code block
    m = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if m:
        return m.group(1).strip()
    # Try JSON array directly
    m = re.search(r"\[[\s\S]*\]", text)
    if m:
        return m.group(0)
    return text.strip()


@router.post("/identify")
async def identify(
    image: UploadFile = File(...),
    _: None = Depends(verify_token),
):
    if not config.ANTHROPIC_KEY:
        raise HTTPException(500, "ANTHROPIC_KEY not configured")

    image_bytes = await image.read()
    b64 = base64.standard_b64encode(image_bytes).decode("ascii")
    media_type = _detect_media_type(image.content_type, image.filename)

    client = anthropic.Anthropic(api_key=config.ANTHROPIC_KEY)

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": PROMPT,
                    },
                ],
            }
        ],
    )

    text_block = next(
        (b.text for b in message.content if b.type == "text"), None
    )
    if not text_block:
        return {"results": []}

    try:
        json_str = _extract_json(text_block)
        parsed = json.loads(json_str)
        results = [
            {
                "name": item["name"],
                "confidence": item.get("confidence", 0.5),
                "description": item.get("description"),
            }
            for item in parsed
        ]
        return {"results": results}
    except (json.JSONDecodeError, KeyError):
        return {"results": []}
