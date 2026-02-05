from fastapi import Header, HTTPException

from . import config


def verify_token(authorization: str = Header(...)) -> None:
    """Bearer トークン認証"""
    if not config.AUTH_TOKEN:
        raise HTTPException(500, "AUTH_TOKEN not configured")

    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Invalid authorization header")

    token = authorization[len("Bearer "):]
    if token != config.AUTH_TOKEN:
        raise HTTPException(401, "Invalid token")
