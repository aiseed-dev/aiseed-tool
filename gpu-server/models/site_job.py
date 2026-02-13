"""サイト生成バッチジョブ — DB モデル

スマホ版: リクエストを蓄積 → バッチ処理 → メール通知
"""

import uuid
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import relationship

from database import Base


class SiteJob(Base):
    __tablename__ = "site_jobs"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    status = Column(String, nullable=False, default="pending")
    # pending → processing → done / error

    # 入力データ (JSON)
    site_data = Column(Text, nullable=False)

    # 出力
    html = Column(Text, nullable=True)
    public_url = Column(String, nullable=True)  # cowork.aiseed.dev/username/
    error_message = Column(String, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", lazy="selectin")
