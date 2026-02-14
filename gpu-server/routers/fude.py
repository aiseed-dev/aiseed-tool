"""筆ポリゴン (農水省農地区画データ) エンドポイント。

- GeoJSON ファイルをアップロードしてインポート
- GPS 座標から農地区画を検索
- 周辺の農地区画一覧を取得
"""

import json
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from services.fude_service import (
    LAND_TYPE_LABELS,
    import_geojson,
    search_by_location,
    search_nearby,
    get_import_stats,
)

router = APIRouter(prefix="/fude", tags=["fude"])


# ---------- Response Models ----------


class FudePolygonResponse(BaseModel):
    polygon_uuid: str
    local_government_cd: str
    land_type: int
    land_type_label: str
    centroid_lat: float
    centroid_lon: float
    area_m2: float | None = None
    issue_year: int
    edit_year: int


class FudePolygonDetailResponse(FudePolygonResponse):
    geometry: dict  # GeoJSON geometry オブジェクト


class ImportResult(BaseModel):
    status: str
    imported: int


class StatsResponse(BaseModel):
    total_polygons: int
    municipalities: int


# ---------- Endpoints ----------


@router.post("/import", response_model=ImportResult)
async def import_fude_data(
    file: UploadFile = File(..., description="GeoJSON または ZIP ファイル"),
    db: AsyncSession = Depends(get_db),
):
    """農水省の筆ポリゴン GeoJSON をインポートする。

    open.fude.maff.go.jp からダウンロードした ZIP または GeoJSON を
    アップロードすると DB に保存される。
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="ファイル名がありません")

    if not file.filename.endswith((".json", ".geojson", ".zip")):
        raise HTTPException(
            status_code=400,
            detail="GeoJSON (.json, .geojson) または ZIP ファイルのみ対応",
        )

    content = await file.read()
    if len(content) > 100 * 1024 * 1024:  # 100MB 上限
        raise HTTPException(status_code=400, detail="ファイルサイズが大きすぎます（上限 100MB）")

    try:
        count = await import_geojson(db, content, file.filename)
    except (ValueError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=400, detail=str(e))

    return ImportResult(status="ok", imported=count)


@router.get("/search", response_model=Optional[FudePolygonDetailResponse])
async def search_field(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    db: AsyncSession = Depends(get_db),
):
    """GPS 座標から筆ポリゴン（農地区画）を検索する。

    スマホの GPS で取得した座標を送ると、その地点が含まれる
    農地区画の情報を返す。データがない場合は null。
    """
    poly = await search_by_location(db, lat, lon)
    if poly is None:
        return None

    return FudePolygonDetailResponse(
        polygon_uuid=poly.polygon_uuid,
        local_government_cd=poly.local_government_cd,
        land_type=poly.land_type,
        land_type_label=LAND_TYPE_LABELS.get(poly.land_type, "不明"),
        centroid_lat=poly.centroid_lat,
        centroid_lon=poly.centroid_lon,
        area_m2=poly.area_m2,
        issue_year=poly.issue_year,
        edit_year=poly.edit_year,
        geometry=json.loads(poly.geometry_json) if poly.geometry_json else {},
    )


@router.get("/nearby", response_model=list[FudePolygonResponse])
async def get_nearby_fields(
    lat: float = Query(..., description="緯度"),
    lon: float = Query(..., description="経度"),
    radius: float = Query(default=0.01, description="検索半径 (度, デフォルト≈1km)"),
    limit: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """GPS 座標の周辺にある農地区画を一覧で返す。"""
    polygons = await search_nearby(db, lat, lon, radius_deg=radius, limit=limit)
    return [
        FudePolygonResponse(
            polygon_uuid=p.polygon_uuid,
            local_government_cd=p.local_government_cd,
            land_type=p.land_type,
            land_type_label=LAND_TYPE_LABELS.get(p.land_type, "不明"),
            centroid_lat=p.centroid_lat,
            centroid_lon=p.centroid_lon,
            area_m2=p.area_m2,
            issue_year=p.issue_year,
            edit_year=p.edit_year,
        )
        for p in polygons
    ]


@router.get("/stats", response_model=StatsResponse)
async def fude_stats(db: AsyncSession = Depends(get_db)):
    """インポート済み筆ポリゴンデータの統計。"""
    stats = await get_import_stats(db)
    return StatsResponse(**stats)
