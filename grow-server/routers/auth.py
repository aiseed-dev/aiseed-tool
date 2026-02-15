from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.user import User
from services.auth_service import (
    register_user,
    authenticate_user,
    create_access_token,
    get_current_user,
)
from services.social_auth_service import social_login_apple, social_login_google

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    username: str
    email: str
    password: str
    display_name: str = ""


class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    display_name: str
    is_active: bool
    role: str = "pending"

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class SocialLoginRequest(BaseModel):
    id_token: str
    display_name: str = ""


class UpdateProfileRequest(BaseModel):
    display_name: str | None = None
    email: str | None = None


@router.post("/register", response_model=TokenResponse)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    if len(req.username) < 3:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="ユーザー名は3文字以上にしてください",
        )
    if len(req.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="パスワードは8文字以上にしてください",
        )

    user = await register_user(
        db,
        username=req.username,
        email=req.email,
        password=req.password,
        display_name=req.display_name,
    )
    token = create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    user = await authenticate_user(db, form_data.username, form_data.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ユーザー名またはパスワードが正しくありません",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )


@router.post("/apple", response_model=TokenResponse)
async def login_apple(
    req: SocialLoginRequest, db: AsyncSession = Depends(get_db)
):
    """Login or register with Apple ID."""
    try:
        user, token = await social_login_apple(
            db, req.id_token, req.display_name
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        )
    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )


@router.post("/google", response_model=TokenResponse)
async def login_google(
    req: SocialLoginRequest, db: AsyncSession = Depends(get_db)
):
    """Login or register with Google ID."""
    try:
        user, token = await social_login_google(db, req.id_token)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        )
    return TokenResponse(
        access_token=token,
        user=UserResponse.model_validate(user),
    )


@router.get("/me", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_user)):
    return UserResponse.model_validate(current_user)


@router.put("/me", response_model=UserResponse)
async def update_profile(
    req: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if req.display_name is not None:
        current_user.display_name = req.display_name
    if req.email is not None:
        current_user.email = req.email
    await db.commit()
    await db.refresh(current_user)
    return UserResponse.model_validate(current_user)
