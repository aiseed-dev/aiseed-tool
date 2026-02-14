"""消費者 API — ユーザー登録・ログイン・いいね

生成されたホームページの JavaScript から呼ばれる。
"""

import logging
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, status
from jose import JWTError, jwt as jose_jwt
from pydantic import BaseModel
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from database import get_db
from models.consumer import Consumer
from models.site_like import SiteLike
from services.auth_service import hash_password, verify_password, create_consumer_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/consumer", tags=["consumer"])


# ── リクエスト / レスポンスモデル ──


class ConsumerRegisterRequest(BaseModel):
    email: str
    password: str
    display_name: str = ""


class ConsumerLoginRequest(BaseModel):
    email: str
    password: str


class ConsumerResponse(BaseModel):
    id: str
    email: str
    display_name: str

    model_config = {"from_attributes": True}


class ConsumerTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    consumer: ConsumerResponse


class LikeResponse(BaseModel):
    liked: bool
    count: int


# ── 認証ヘルパー ──


async def _resolve_consumer(
    authorization: str | None,
    db: AsyncSession,
) -> Consumer | None:
    """Authorization ヘッダーから消費者を取得。任意認証（None 返却あり）。"""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization[7:]

    try:
        payload = jose_jwt.decode(
            token, settings.secret_key, algorithms=[settings.algorithm]
        )
        consumer_id: str = payload.get("sub")
        role: str = payload.get("role", "")
        if consumer_id is None or role != "consumer":
            return None
    except JWTError:
        return None

    result = await db.execute(
        select(Consumer).where(Consumer.id == consumer_id)
    )
    consumer = result.scalar_one_or_none()
    if consumer is None or not consumer.is_active:
        return None
    return consumer


# ── エンドポイント ──


@router.post("/register", response_model=ConsumerTokenResponse)
async def register(req: ConsumerRegisterRequest, db: AsyncSession = Depends(get_db)):
    """消費者ユーザー登録。"""
    if len(req.password) < 6:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="パスワードは6文字以上にしてください",
        )

    result = await db.execute(
        select(Consumer).where(Consumer.email == req.email)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="このメールアドレスは既に登録されています",
        )

    consumer = Consumer(
        id=str(uuid4()),
        email=req.email,
        hashed_password=hash_password(req.password),
        display_name=req.display_name or req.email.split("@")[0],
    )
    db.add(consumer)
    await db.commit()
    await db.refresh(consumer)

    token = create_consumer_token(consumer.id)
    return ConsumerTokenResponse(
        access_token=token,
        consumer=ConsumerResponse.model_validate(consumer),
    )


@router.post("/login", response_model=ConsumerTokenResponse)
async def login(req: ConsumerLoginRequest, db: AsyncSession = Depends(get_db)):
    """消費者ログイン。"""
    result = await db.execute(
        select(Consumer).where(Consumer.email == req.email)
    )
    consumer = result.scalar_one_or_none()
    if consumer is None or not verify_password(req.password, consumer.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="メールアドレスまたはパスワードが正しくありません",
        )

    token = create_consumer_token(consumer.id)
    return ConsumerTokenResponse(
        access_token=token,
        consumer=ConsumerResponse.model_validate(consumer),
    )


@router.post("/like/{farm_username}", response_model=LikeResponse)
async def toggle_like(
    farm_username: str,
    db: AsyncSession = Depends(get_db),
    authorization: Optional[str] = Header(default=None),
):
    """いいねのトグル（ログイン必須）。"""
    consumer = await _resolve_consumer(authorization, db)
    if consumer is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ログインが必要です",
        )

    # 既存のいいねを確認
    result = await db.execute(
        select(SiteLike).where(
            SiteLike.farm_username == farm_username,
            SiteLike.consumer_id == consumer.id,
        )
    )
    existing = result.scalar_one_or_none()

    if existing:
        await db.execute(
            delete(SiteLike).where(SiteLike.id == existing.id)
        )
        await db.commit()
        liked = False
    else:
        like = SiteLike(
            farm_username=farm_username,
            consumer_id=consumer.id,
        )
        db.add(like)
        await db.commit()
        liked = True

    # 最新カウント
    count_result = await db.execute(
        select(func.count()).select_from(SiteLike).where(
            SiteLike.farm_username == farm_username
        )
    )
    count = count_result.scalar() or 0

    return LikeResponse(liked=liked, count=count)


@router.get("/likes/{farm_username}")
async def get_likes(
    farm_username: str,
    db: AsyncSession = Depends(get_db),
    authorization: Optional[str] = Header(default=None),
):
    """いいね数と自分がいいね済みかを返す（未ログインでも数は見える）。"""
    count_result = await db.execute(
        select(func.count()).select_from(SiteLike).where(
            SiteLike.farm_username == farm_username
        )
    )
    count = count_result.scalar() or 0

    liked = False
    consumer = await _resolve_consumer(authorization, db)
    if consumer:
        result = await db.execute(
            select(SiteLike).where(
                SiteLike.farm_username == farm_username,
                SiteLike.consumer_id == consumer.id,
            )
        )
        liked = result.scalar_one_or_none() is not None

    return {"count": count, "liked": liked}
