"""農水省 筆ポリゴンデータのキャッシュモデル。

GeoJSON ファイルからインポートした農地区画情報を保持する。
GPS 座標で区画を検索し、栽培場所の特定に使う。
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Float, Integer, String, Text, Index
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class FudePolygon(Base):
    """筆ポリゴン（農地区画）。"""

    __tablename__ = "fude_polygons"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # 農水省が付与する UUID
    polygon_uuid: Mapped[str] = mapped_column(String(40), unique=True, index=True)

    # 自治体コード (JIS) — 例: "122041"
    local_government_cd: Mapped[str] = mapped_column(String(10), index=True)

    # 土地利用区分: 100=田, 200=畑
    land_type: Mapped[int] = mapped_column(Integer, default=0)

    # 重心座標（高速なバウンディング検索用）
    centroid_lat: Mapped[float] = mapped_column(Float, default=0.0)
    centroid_lon: Mapped[float] = mapped_column(Float, default=0.0)

    # バウンディングボックス（粗い範囲絞り込み用）
    bbox_min_lat: Mapped[float] = mapped_column(Float, default=0.0)
    bbox_max_lat: Mapped[float] = mapped_column(Float, default=0.0)
    bbox_min_lon: Mapped[float] = mapped_column(Float, default=0.0)
    bbox_max_lon: Mapped[float] = mapped_column(Float, default=0.0)

    # ポリゴン座標 — GeoJSON geometry をそのまま JSON 文字列で保存
    geometry_json: Mapped[str] = mapped_column(Text, default="")

    # 面積（m²） — 後からインポート時に概算計算
    area_m2: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # メタデータ
    issue_year: Mapped[int] = mapped_column(Integer, default=0)
    edit_year: Mapped[int] = mapped_column(Integer, default=0)

    imported_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    __table_args__ = (
        Index("ix_fude_bbox", "bbox_min_lat", "bbox_max_lat",
              "bbox_min_lon", "bbox_max_lon"),
    )
