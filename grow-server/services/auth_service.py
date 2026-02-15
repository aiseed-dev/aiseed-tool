from datetime import datetime, timedelta, timezone
from uuid import uuid4

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel

from config import settings
from database import get_db
from models.user import User, ROLE_PENDING, ROLE_USER, ROLE_SUPER_USER, ROLE_ADMIN

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


class TokenData(BaseModel):
    user_id: str


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    payload = {"sub": user_id, "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def create_consumer_token(consumer_id: str) -> str:
    """消費者用トークン（role=consumer で農家トークンと区別）。"""
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    payload = {"sub": consumer_id, "role": "consumer", "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="認証情報が無効です",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token, settings.secret_key, algorithms=[settings.algorithm]
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise credentials_exception
    return user


def require_feature(feature: str):
    """機能単位のアクセス制御 Dependency。

    - admin: 全機能許可
    - super_user: 全機能許可（admin管理以外）
    - user: users.yaml で許可された機能のみ
    - pending: すべて拒否
    """
    async def checker(current_user: User = Depends(get_current_user)):
        role = getattr(current_user, "role", ROLE_PENDING)

        # admin / super_user は無条件で許可
        if role in (ROLE_ADMIN, ROLE_SUPER_USER):
            return current_user

        # pending は全拒否
        if role == ROLE_PENDING:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="アカウントが承認されていません",
            )

        # role=user → users.yaml をチェック
        from services.feature_config import get_user_features
        allowed = get_user_features(current_user.username)
        if allowed is None:
            # 設定ファイルに記載なし → 拒否
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="利用可能な機能が設定されていません",
            )
        if feature not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"この機能（{feature}）は許可されていません",
            )
        return current_user
    return checker


# 管理者のみ
def _require_admin():
    async def checker(current_user: User = Depends(get_current_user)):
        if getattr(current_user, "role", ROLE_PENDING) != ROLE_ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="管理者権限が必要です",
            )
        return current_user
    return checker

get_admin_user = _require_admin()

# 後方互換: get_approved_user は pending 以外を許可
def _require_not_pending():
    async def checker(current_user: User = Depends(get_current_user)):
        if getattr(current_user, "role", ROLE_PENDING) == ROLE_PENDING:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="アカウントが承認されていません",
            )
        return current_user
    return checker

get_approved_user = _require_not_pending()


async def register_user(
    db: AsyncSession, username: str, email: str, password: str, display_name: str = ""
) -> User:
    # Check existing
    result = await db.execute(
        select(User).where((User.username == username) | (User.email == email))
    )
    existing = result.scalar_one_or_none()
    if existing:
        if existing.username == username:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="このユーザー名は既に使われています",
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="このメールアドレスは既に使われています",
        )

    user = User(
        id=str(uuid4()),
        username=username,
        email=email,
        hashed_password=hash_password(password),
        display_name=display_name or username,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def authenticate_user(
    db: AsyncSession, username: str, password: str
) -> User | None:
    result = await db.execute(
        select(User).where(
            (User.username == username) | (User.email == username)
        )
    )
    user = result.scalar_one_or_none()
    if user is None or not verify_password(password, user.hashed_password):
        return None
    return user
