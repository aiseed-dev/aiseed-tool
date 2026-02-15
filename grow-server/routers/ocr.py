import os
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from pydantic import BaseModel

from config import settings
from models.user import User
from services.auth_service import get_approved_user
from services.ocr_service import run_ocr, extract_seed_packet_info

router = APIRouter(prefix="/ocr", tags=["ocr"])


class OcrResponse(BaseModel):
    lines: list[dict]
    raw_text: str


class SeedPacketResponse(BaseModel):
    raw_text: str
    crop_name: str
    variety: str
    lines: list[str]
    crop_name_candidates: list[str]


@router.post("/read", response_model=OcrResponse)
async def ocr_read(
    file: UploadFile = File(...),
    current_user: User = Depends(get_approved_user),
):
    """Run OCR on an uploaded image. Returns all detected text lines."""
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="画像ファイルをアップロードしてください")

    # Save temp file
    ext = Path(file.filename or "image.jpg").suffix or ".jpg"
    temp_path = os.path.join(settings.upload_dir, f"{uuid.uuid4()}{ext}")
    try:
        content = await file.read()
        if len(content) > settings.max_upload_size:
            raise HTTPException(status_code=413, detail="ファイルサイズが大きすぎます")

        with open(temp_path, "wb") as f:
            f.write(content)

        result = run_ocr(temp_path)
        return OcrResponse(lines=result.lines, raw_text=result.raw_text)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


@router.post("/seed-packet", response_model=SeedPacketResponse)
async def ocr_seed_packet(
    file: UploadFile = File(...),
    current_user: User = Depends(get_approved_user),
):
    """Read a seed packet image and extract crop name and cultivation info."""
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="画像ファイルをアップロードしてください")

    ext = Path(file.filename or "image.jpg").suffix or ".jpg"
    temp_path = os.path.join(settings.upload_dir, f"{uuid.uuid4()}{ext}")
    try:
        content = await file.read()
        if len(content) > settings.max_upload_size:
            raise HTTPException(status_code=413, detail="ファイルサイズが大きすぎます")

        with open(temp_path, "wb") as f:
            f.write(content)

        ocr_result = run_ocr(temp_path)
        info = extract_seed_packet_info(ocr_result)
        return SeedPacketResponse(**info)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
