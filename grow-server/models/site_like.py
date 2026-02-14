"""サイトいいね — 消費者が農家ホームページに「いいね」する

farm_username = サイトオーナー（農家）のユーザー名
consumer_id  = いいねした消費者
"""

import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class SiteLike(Base):
    __tablename__ = "site_likes"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    farm_username: Mapped[str] = mapped_column(String(50), index=True)
    consumer_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("consumers.id"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    __table_args__ = (
        UniqueConstraint("farm_username", "consumer_id", name="uq_like_per_consumer"),
    )
