"""
栽培データ CRUD — スマホ・PC・CLI 共通エンドポイント

POST   /grow/sync/push  — クライアントからデータ一括送信
POST   /grow/sync/pull  — サーバーの更新データ取得
POST   /grow/photos     — 写真アップロード
GET    /grow/photos/{photo_id}  — 写真取得
"""

import os
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from database import get_db
from models.grow import (
    Location, Plot, Crop, Record, RecordPhoto,
    Observation, ObservationEntry,
)
from models.user import User
from services.auth_service import get_current_user

router = APIRouter(prefix="/grow", tags=["grow"])

# ─── Pydantic Schemas ───

class LocationSchema(BaseModel):
    id: str
    name: str
    description: str = ""
    environment_type: int = 0
    latitude: float | None = None
    longitude: float | None = None
    created_at: str
    updated_at: str
    model_config = {"from_attributes": True}

class PlotSchema(BaseModel):
    id: str
    location_id: str
    name: str
    cover_type: int = 0
    soil_type: int = 0
    memo: str = ""
    created_at: str
    updated_at: str
    model_config = {"from_attributes": True}

class CropSchema(BaseModel):
    id: str
    cultivation_name: str
    name: str = ""
    variety: str = ""
    plot_id: str | None = None
    parent_crop_id: str | None = None
    farming_method: str | None = None
    memo: str = ""
    start_date: str
    created_at: str
    updated_at: str
    model_config = {"from_attributes": True}

class RecordSchema(BaseModel):
    id: str
    crop_id: str | None = None
    location_id: str | None = None
    plot_id: str | None = None
    activity_type: int = 0
    date: str
    note: str = ""
    created_at: str
    updated_at: str
    model_config = {"from_attributes": True}

class RecordPhotoSchema(BaseModel):
    id: str
    record_id: str
    file_path: str
    sort_order: int = 0
    created_at: str
    updated_at: str
    model_config = {"from_attributes": True}

class ObservationSchema(BaseModel):
    id: str
    location_id: str | None = None
    plot_id: str | None = None
    category: int = 0
    date: str
    memo: str = ""
    created_at: str
    updated_at: str
    model_config = {"from_attributes": True}

class ObservationEntrySchema(BaseModel):
    id: str
    observation_id: str
    key: str
    value: float
    unit: str = ""
    updated_at: str
    model_config = {"from_attributes": True}

class DeletedRecord(BaseModel):
    id: str
    table_name: str

class SyncPullRequest(BaseModel):
    since: str = "1970-01-01T00:00:00"

class SyncPushRequest(BaseModel):
    locations: list[LocationSchema] = []
    plots: list[PlotSchema] = []
    crops: list[CropSchema] = []
    records: list[RecordSchema] = []
    record_photos: list[RecordPhotoSchema] = []
    observations: list[ObservationSchema] = []
    observation_entries: list[ObservationEntrySchema] = []
    deleted: list[DeletedRecord] = []

class SyncPullResponse(BaseModel):
    locations: list[LocationSchema] = []
    plots: list[PlotSchema] = []
    crops: list[CropSchema] = []
    records: list[RecordSchema] = []
    record_photos: list[RecordPhotoSchema] = []
    observations: list[ObservationSchema] = []
    observation_entries: list[ObservationEntrySchema] = []
    timestamp: str

# ─── 同期テーブルのマッピング ───

TABLE_MAP = {
    "locations": Location,
    "plots": Plot,
    "crops": Crop,
    "records": Record,
    "record_photos": RecordPhoto,
    "observations": Observation,
    "observation_entries": ObservationEntry,
}

def _parse_dt(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))

def _dt_str(dt: datetime) -> str:
    return dt.isoformat()

def _model_to_dict(obj) -> dict:
    """SQLAlchemy model → dict with datetime as ISO string."""
    d = {}
    for col in obj.__table__.columns:
        val = getattr(obj, col.name)
        if isinstance(val, datetime):
            val = _dt_str(val)
        d[col.name] = val
    return d

# ─── Sync Pull ───

@router.post("/sync/pull", response_model=SyncPullResponse)
async def sync_pull(
    req: SyncPullRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    since = _parse_dt(req.since)
    now = datetime.utcnow()
    result = {}

    for table_name, model_cls in TABLE_MAP.items():
        stmt = select(model_cls).where(model_cls.updated_at > since)
        rows = (await db.execute(stmt)).scalars().all()
        result[table_name] = [_model_to_dict(r) for r in rows]

    return SyncPullResponse(**result, timestamp=_dt_str(now))

# ─── Sync Push ───

@router.post("/sync/push")
async def sync_push(
    req: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()

    for table_name, model_cls in TABLE_MAP.items():
        rows = getattr(req, table_name, [])
        for row in rows:
            data = row.model_dump()
            # datetime 文字列 → datetime オブジェクト
            for key, val in data.items():
                col = model_cls.__table__.columns.get(key)
                if col is not None and isinstance(col.type, type(model_cls.__table__.columns["updated_at"].type)):
                    try:
                        data[key] = _parse_dt(val) if isinstance(val, str) else val
                    except (ValueError, TypeError):
                        pass

            existing = await db.get(model_cls, data["id"])
            if existing:
                for key, val in data.items():
                    if key != "id":
                        setattr(existing, key, val)
            else:
                db.add(model_cls(**data))

    # 削除処理
    for deleted in req.deleted:
        model_cls = TABLE_MAP.get(deleted.table_name)
        if model_cls is None:
            continue
        obj = await db.get(model_cls, deleted.id)
        if obj:
            await db.delete(obj)

    await db.commit()
    return {"ok": True, "timestamp": _dt_str(now)}

# ─── 写真アップロード ───

@router.post("/photos")
async def upload_photo(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    if image.size and image.size > settings.max_upload_size:
        raise HTTPException(status_code=413, detail="File too large")

    now = datetime.utcnow()
    date_dir = now.strftime("%Y/%m/%d")
    save_dir = os.path.join(settings.upload_dir, date_dir)
    os.makedirs(save_dir, exist_ok=True)

    ext = os.path.splitext(image.filename or "photo.jpg")[1] or ".jpg"
    filename = f"{now.strftime('%H%M%S')}-{uuid.uuid4().hex[:8]}{ext}"
    file_path = os.path.join(save_dir, filename)

    content = await image.read()
    with open(file_path, "wb") as f:
        f.write(content)

    # URL パス (サーバーから配信用)
    relative_path = f"{date_dir}/{filename}"
    return {"path": relative_path, "size": len(content)}

# ─── 写真取得 ───

@router.get("/photos/{path:path}")
async def get_photo(path: str):
    file_path = os.path.join(settings.upload_dir, path)
    if not os.path.isfile(file_path):
        raise HTTPException(status_code=404, detail="Not found")

    from fastapi.responses import FileResponse
    return FileResponse(
        file_path,
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )
