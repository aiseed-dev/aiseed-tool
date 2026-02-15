import os
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from pydantic import BaseModel

from config import settings
from models.user import User
from services.auth_service import get_approved_user
from services.vision_service import run_caption, run_detect, analyze_plant_photo

router = APIRouter(prefix="/vision", tags=["vision"])


class CaptionResponse(BaseModel):
    caption: str


class DetectRequest(BaseModel):
    target: str = ""


class DetectionResult(BaseModel):
    bboxes: list[list[float]] = []
    labels: list[str] = []


class DetectResponse(BaseModel):
    detections: DetectionResult


class AnalyzeResponse(BaseModel):
    caption: str
    detections: dict


async def _save_upload(file: UploadFile) -> str:
    """Save uploaded file to temp path, return path."""
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="画像ファイルをアップロードしてください")

    ext = Path(file.filename or "image.jpg").suffix or ".jpg"
    temp_path = os.path.join(settings.upload_dir, f"{uuid.uuid4()}{ext}")

    content = await file.read()
    if len(content) > settings.max_upload_size:
        raise HTTPException(status_code=413, detail="ファイルサイズが大きすぎます")

    with open(temp_path, "wb") as f:
        f.write(content)
    return temp_path


@router.post("/caption", response_model=CaptionResponse)
async def caption_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_approved_user),
):
    """Generate a detailed caption for the uploaded image."""
    temp_path = await _save_upload(file)
    try:
        caption = run_caption(temp_path)
        return CaptionResponse(caption=caption)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


@router.post("/detect", response_model=DetectResponse)
async def detect_objects(
    file: UploadFile = File(...),
    target: str = "",
    current_user: User = Depends(get_approved_user),
):
    """Detect objects in the uploaded image.

    Optionally provide a target to search for specific objects.
    """
    temp_path = await _save_upload(file)
    try:
        result = run_detect(temp_path, target=target)
        return DetectResponse(detections=result)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_photo(
    file: UploadFile = File(...),
    current_user: User = Depends(get_approved_user),
):
    """Analyze a plant/garden photo.

    Returns caption and detected objects.
    """
    temp_path = await _save_upload(file)
    try:
        result = analyze_plant_photo(temp_path)
        return AnalyzeResponse(**result)
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
