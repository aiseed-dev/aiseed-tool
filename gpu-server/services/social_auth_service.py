"""Apple ID / Google ID token verification and social login."""

import logging
from uuid import uuid4

import httpx
from jose import jwt, JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from models.user import User
from services.auth_service import create_access_token

logger = logging.getLogger(__name__)

# Apple public keys cache
_apple_keys: list[dict] | None = None
# Google public keys cache
_google_keys: list[dict] | None = None


# ---------- Apple Sign In ----------


async def _fetch_apple_keys() -> list[dict]:
    """Fetch Apple's public keys for JWT verification."""
    global _apple_keys
    if _apple_keys is not None:
        return _apple_keys

    async with httpx.AsyncClient() as client:
        resp = await client.get("https://appleid.apple.com/auth/keys")
        resp.raise_for_status()
        data = resp.json()
        _apple_keys = data["keys"]
        return _apple_keys


async def verify_apple_token(id_token: str) -> dict | None:
    """Verify an Apple ID token and return claims.

    Returns dict with 'sub' (Apple user ID), 'email', 'email_verified'.
    Returns None if verification fails.
    """
    try:
        keys = await _fetch_apple_keys()

        # Decode header to find the right key
        header = jwt.get_unverified_header(id_token)
        kid = header.get("kid")

        matching_key = None
        for key in keys:
            if key["kid"] == kid:
                matching_key = key
                break

        if matching_key is None:
            logger.warning("Apple token: no matching key found for kid=%s", kid)
            # Refresh keys and retry
            global _apple_keys
            _apple_keys = None
            keys = await _fetch_apple_keys()
            for key in keys:
                if key["kid"] == kid:
                    matching_key = key
                    break

        if matching_key is None:
            return None

        claims = jwt.decode(
            id_token,
            matching_key,
            algorithms=["RS256"],
            audience=settings.apple_client_id,
            issuer="https://appleid.apple.com",
        )

        return {
            "sub": claims["sub"],
            "email": claims.get("email", ""),
            "email_verified": claims.get("email_verified", False),
        }
    except JWTError as e:
        logger.warning("Apple token verification failed: %s", e)
        return None
    except Exception as e:
        logger.error("Apple token error: %s", e)
        return None


# ---------- Google Sign In ----------


async def _fetch_google_keys() -> list[dict]:
    """Fetch Google's public keys for JWT verification."""
    global _google_keys
    if _google_keys is not None:
        return _google_keys

    async with httpx.AsyncClient() as client:
        resp = await client.get("https://www.googleapis.com/oauth2/v3/certs")
        resp.raise_for_status()
        data = resp.json()
        _google_keys = data["keys"]
        return _google_keys


async def verify_google_token(id_token: str) -> dict | None:
    """Verify a Google ID token and return claims.

    Returns dict with 'sub' (Google user ID), 'email', 'name', 'picture'.
    Returns None if verification fails.
    """
    try:
        keys = await _fetch_google_keys()

        header = jwt.get_unverified_header(id_token)
        kid = header.get("kid")

        matching_key = None
        for key in keys:
            if key["kid"] == kid:
                matching_key = key
                break

        if matching_key is None:
            global _google_keys
            _google_keys = None
            keys = await _fetch_google_keys()
            for key in keys:
                if key["kid"] == kid:
                    matching_key = key
                    break

        if matching_key is None:
            return None

        claims = jwt.decode(
            id_token,
            matching_key,
            algorithms=["RS256"],
            audience=settings.google_client_id,
            issuer=["accounts.google.com", "https://accounts.google.com"],
        )

        return {
            "sub": claims["sub"],
            "email": claims.get("email", ""),
            "name": claims.get("name", ""),
            "picture": claims.get("picture", ""),
        }
    except JWTError as e:
        logger.warning("Google token verification failed: %s", e)
        return None
    except Exception as e:
        logger.error("Google token error: %s", e)
        return None


# ---------- Social Login Logic ----------


async def social_login_apple(
    db: AsyncSession, id_token: str, display_name: str = ""
) -> tuple[User, str]:
    """Login or register with Apple ID.

    Returns (user, access_token).
    Raises ValueError if token is invalid.
    """
    claims = await verify_apple_token(id_token)
    if claims is None:
        raise ValueError("Apple IDトークンの検証に失敗しました")

    apple_sub = claims["sub"]
    email = claims.get("email", "")

    # Find existing user by apple_id
    result = await db.execute(select(User).where(User.apple_id == apple_sub))
    user = result.scalar_one_or_none()

    if user is None and email:
        # Check if email already exists (link accounts)
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user is not None:
            user.apple_id = apple_sub
            await db.commit()
            await db.refresh(user)

    if user is None:
        # New user registration
        username = f"apple_{apple_sub[:8]}"
        # Ensure unique username
        base = username
        counter = 1
        while True:
            result = await db.execute(
                select(User).where(User.username == username)
            )
            if result.scalar_one_or_none() is None:
                break
            username = f"{base}_{counter}"
            counter += 1

        user = User(
            id=str(uuid4()),
            username=username,
            email=email or f"{apple_sub[:8]}@apple.private",
            hashed_password="",
            display_name=display_name or username,
            apple_id=apple_sub,
            auth_provider="apple",
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    token = create_access_token(user.id)
    return user, token


async def social_login_google(
    db: AsyncSession, id_token: str
) -> tuple[User, str]:
    """Login or register with Google ID.

    Returns (user, access_token).
    Raises ValueError if token is invalid.
    """
    claims = await verify_google_token(id_token)
    if claims is None:
        raise ValueError("Google IDトークンの検証に失敗しました")

    google_sub = claims["sub"]
    email = claims.get("email", "")
    name = claims.get("name", "")

    # Find existing user by google_id
    result = await db.execute(select(User).where(User.google_id == google_sub))
    user = result.scalar_one_or_none()

    if user is None and email:
        # Check if email already exists (link accounts)
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user is not None:
            user.google_id = google_sub
            await db.commit()
            await db.refresh(user)

    if user is None:
        # New user registration
        username = f"google_{google_sub[:8]}"
        base = username
        counter = 1
        while True:
            result = await db.execute(
                select(User).where(User.username == username)
            )
            if result.scalar_one_or_none() is None:
                break
            username = f"{base}_{counter}"
            counter += 1

        user = User(
            id=str(uuid4()),
            username=username,
            email=email,
            hashed_password="",
            display_name=name or username,
            google_id=google_sub,
            auth_provider="google",
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    token = create_access_token(user.id)
    return user, token
