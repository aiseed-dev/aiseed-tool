"""管理者用ユーザー管理API。

admin ロールのユーザーのみアクセス可能。
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.user import User, ROLE_PENDING, ROLE_USER, ROLE_ADMIN
from services.auth_service import get_admin_user

router = APIRouter(prefix="/admin", tags=["admin"])


class UserSummary(BaseModel):
    id: str
    username: str
    email: str
    display_name: str
    role: str
    is_active: bool
    auth_provider: str
    created_at: str

    model_config = {"from_attributes": True}


class UpdateRoleRequest(BaseModel):
    role: str  # "pending", "user", "admin"


class UserStats(BaseModel):
    total: int
    pending: int
    active: int
    admin: int
    inactive: int


def _user_to_summary(user: User) -> UserSummary:
    return UserSummary(
        id=user.id,
        username=user.username,
        email=user.email,
        display_name=user.display_name,
        role=getattr(user, "role", ROLE_PENDING),
        is_active=user.is_active,
        auth_provider=user.auth_provider,
        created_at=user.created_at.isoformat() if user.created_at else "",
    )


@router.get("/users", response_model=list[UserSummary])
async def list_users(
    role: str | None = Query(default=None, description="ロールでフィルタ"),
    _admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """全ユーザー一覧。"""
    q = select(User).order_by(User.created_at.desc())
    if role:
        q = q.where(User.role == role)
    result = await db.execute(q)
    users = result.scalars().all()
    return [_user_to_summary(u) for u in users]


@router.get("/users/stats", response_model=UserStats)
async def user_stats(
    _admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """ユーザー統計。"""
    total = (await db.execute(select(func.count(User.id)))).scalar() or 0
    pending = (await db.execute(
        select(func.count(User.id)).where(User.role == ROLE_PENDING)
    )).scalar() or 0
    admin = (await db.execute(
        select(func.count(User.id)).where(User.role == ROLE_ADMIN)
    )).scalar() or 0
    inactive = (await db.execute(
        select(func.count(User.id)).where(User.is_active == False)
    )).scalar() or 0
    active = total - pending - inactive

    return UserStats(
        total=total, pending=pending, active=active, admin=admin, inactive=inactive
    )


@router.get("/users/pending", response_model=list[UserSummary])
async def pending_users(
    _admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """承認待ちユーザー一覧。"""
    result = await db.execute(
        select(User).where(User.role == ROLE_PENDING).order_by(User.created_at.desc())
    )
    users = result.scalars().all()
    return [_user_to_summary(u) for u in users]


@router.put("/users/{user_id}/approve", response_model=UserSummary)
async def approve_user(
    user_id: str,
    _admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """ユーザーを承認（pending → user）。"""
    user = await _get_user_or_404(db, user_id)
    user.role = ROLE_USER
    user.is_active = True
    await db.commit()
    await db.refresh(user)
    return _user_to_summary(user)


@router.put("/users/{user_id}/role", response_model=UserSummary)
async def update_role(
    user_id: str,
    req: UpdateRoleRequest,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """ユーザーのロールを変更。"""
    if req.role not in (ROLE_PENDING, ROLE_USER, ROLE_ADMIN):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"無効なロール: {req.role}（pending, user, admin のいずれか）",
        )
    user = await _get_user_or_404(db, user_id)
    # 自分自身のadminロールは変更不可
    if user.id == admin.id and req.role != ROLE_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="自分自身のadminロールは削除できません",
        )
    user.role = req.role
    await db.commit()
    await db.refresh(user)
    return _user_to_summary(user)


@router.put("/users/{user_id}/deactivate", response_model=UserSummary)
async def deactivate_user(
    user_id: str,
    admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """ユーザーを無効化。"""
    user = await _get_user_or_404(db, user_id)
    if user.id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="自分自身を無効化できません",
        )
    user.is_active = False
    await db.commit()
    await db.refresh(user)
    return _user_to_summary(user)


@router.put("/users/{user_id}/activate", response_model=UserSummary)
async def activate_user(
    user_id: str,
    _admin: User = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    """ユーザーを有効化。"""
    user = await _get_user_or_404(db, user_id)
    user.is_active = True
    await db.commit()
    await db.refresh(user)
    return _user_to_summary(user)


async def _get_user_or_404(db: AsyncSession, user_id: str) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="ユーザーが見つかりません",
        )
    return user
