"""写真ストレージ（ローカルファイルシステム）

Cloudflare Workers 版の R2 と同じ API 仕様:
  POST   /photos         - アップロード
  GET    /photos          - 一覧
  GET    /photos/{key:path} - ダウンロード
  DELETE /photos/{key:path} - 削除
"""

import secrets
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, Request, UploadFile, File
from fastapi.responses import FileResponse

from .auth import verify_token
from . import config

router = APIRouter()


def _generate_key(filename: str) -> str:
    now = datetime.now(timezone.utc)
    date_path = now.strftime("%Y/%m/%d")
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "jpg"
    rand = secrets.token_hex(6)
    return f"{date_path}/{int(now.timestamp() * 1000)}-{rand}.{ext}"


@router.post("/photos")
async def upload_photo(
    image: UploadFile = File(...),
    _: None = Depends(verify_token),
):
    key = _generate_key(image.filename or "photo.jpg")
    dest = config.PHOTOS_DIR / key
    dest.parent.mkdir(parents=True, exist_ok=True)

    content = await image.read()
    dest.write_bytes(content)

    return {"key": key, "size": len(content)}


@router.get("/photos")
async def list_photos(
    prefix: str = Query(default=""),
    cursor: str = Query(default=""),
    _: None = Depends(verify_token),
):
    base = config.PHOTOS_DIR
    search_dir = base / prefix if prefix else base

    if not search_dir.exists():
        return {"items": [], "cursor": None}

    all_files = sorted(search_dir.rglob("*"))
    all_files = [f for f in all_files if f.is_file()]

    # Simple cursor: skip files until we find cursor key
    start = 0
    if cursor:
        for i, f in enumerate(all_files):
            if str(f.relative_to(base)) == cursor:
                start = i + 1
                break

    limit = 100
    page = all_files[start : start + limit]

    items = []
    for f in page:
        rel = str(f.relative_to(base))
        stat = f.stat()
        items.append({
            "key": rel,
            "size": stat.st_size,
            "uploaded": datetime.fromtimestamp(
                stat.st_mtime, tz=timezone.utc
            ).isoformat(),
        })

    next_cursor = None
    if start + limit < len(all_files):
        next_cursor = str(all_files[start + limit].relative_to(base))

    return {"items": items, "cursor": next_cursor}


@router.get("/photos/{key:path}")
async def get_photo(
    key: str,
    _: None = Depends(verify_token),
):
    file_path = config.PHOTOS_DIR / key

    # Prevent path traversal
    try:
        file_path.resolve().relative_to(config.PHOTOS_DIR.resolve())
    except ValueError:
        raise HTTPException(403, "Forbidden")

    if not file_path.exists():
        raise HTTPException(404, "Not found")

    return FileResponse(
        file_path,
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )


@router.delete("/photos/{key:path}")
async def delete_photo(
    key: str,
    _: None = Depends(verify_token),
):
    file_path = config.PHOTOS_DIR / key

    try:
        file_path.resolve().relative_to(config.PHOTOS_DIR.resolve())
    except ValueError:
        raise HTTPException(403, "Forbidden")

    if file_path.exists():
        file_path.unlink()

    return {"deleted": True}
