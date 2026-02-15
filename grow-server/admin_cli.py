"""管理CLIツール — ユーザー管理をコマンドラインで行う。

Usage:
    python admin_cli.py list                    # 全ユーザー一覧
    python admin_cli.py pending                 # 承認待ち一覧
    python admin_cli.py approve <username>      # ユーザーを承認
    python admin_cli.py set-admin <username>    # 管理者に昇格
    python admin_cli.py deactivate <username>   # ユーザーを無効化
    python admin_cli.py activate <username>     # ユーザーを有効化
    python admin_cli.py create-admin <username> <email> <password>  # 初期管理者作成
"""

import asyncio
import sys

from sqlalchemy import select
from database import async_session, init_db
from models.user import User, ROLE_PENDING, ROLE_USER, ROLE_ADMIN
from services.auth_service import hash_password
from uuid import uuid4


async def list_users(role_filter: str | None = None):
    """ユーザー一覧を表示。"""
    async with async_session() as db:
        q = select(User).order_by(User.created_at.desc())
        if role_filter:
            q = q.where(User.role == role_filter)
        result = await db.execute(q)
        users = result.scalars().all()

    if not users:
        print("ユーザーなし")
        return

    print(f"{'username':<20} {'role':<10} {'active':<8} {'provider':<10} {'email'}")
    print("-" * 80)
    for u in users:
        role = getattr(u, "role", "pending")
        print(f"{u.username:<20} {role:<10} {'○' if u.is_active else '×':<8} {u.auth_provider:<10} {u.email}")
    print(f"\n合計: {len(users)} 件")


async def approve_user(username: str):
    """ユーザーを承認。"""
    async with async_session() as db:
        user = await _find_user(db, username)
        if not user:
            return
        user.role = ROLE_USER
        user.is_active = True
        await db.commit()
        print(f"承認しました: {username} → role=user")


async def set_admin(username: str):
    """ユーザーを管理者に昇格。"""
    async with async_session() as db:
        user = await _find_user(db, username)
        if not user:
            return
        user.role = ROLE_ADMIN
        user.is_active = True
        await db.commit()
        print(f"管理者に昇格: {username} → role=admin")


async def deactivate_user(username: str):
    """ユーザーを無効化。"""
    async with async_session() as db:
        user = await _find_user(db, username)
        if not user:
            return
        user.is_active = False
        await db.commit()
        print(f"無効化しました: {username}")


async def activate_user(username: str):
    """ユーザーを有効化。"""
    async with async_session() as db:
        user = await _find_user(db, username)
        if not user:
            return
        user.is_active = True
        await db.commit()
        print(f"有効化しました: {username}")


async def create_admin(username: str, email: str, password: str):
    """初期管理者ユーザーを作成。"""
    await init_db()
    async with async_session() as db:
        # 既存チェック
        result = await db.execute(
            select(User).where((User.username == username) | (User.email == email))
        )
        existing = result.scalar_one_or_none()
        if existing:
            print(f"エラー: ユーザー名またはメールが既に存在します")
            return

        user = User(
            id=str(uuid4()),
            username=username,
            email=email,
            hashed_password=hash_password(password),
            display_name=username,
            role=ROLE_ADMIN,
            is_active=True,
        )
        db.add(user)
        await db.commit()
        print(f"管理者を作成しました: {username} ({email})")


async def _find_user(db, username: str) -> User | None:
    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if user is None:
        print(f"エラー: ユーザー '{username}' が見つかりません")
    return user


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "list":
        asyncio.run(list_users())
    elif cmd == "pending":
        asyncio.run(list_users(ROLE_PENDING))
    elif cmd == "approve" and len(sys.argv) >= 3:
        asyncio.run(approve_user(sys.argv[2]))
    elif cmd == "set-admin" and len(sys.argv) >= 3:
        asyncio.run(set_admin(sys.argv[2]))
    elif cmd == "deactivate" and len(sys.argv) >= 3:
        asyncio.run(deactivate_user(sys.argv[2]))
    elif cmd == "activate" and len(sys.argv) >= 3:
        asyncio.run(activate_user(sys.argv[2]))
    elif cmd == "create-admin" and len(sys.argv) >= 5:
        asyncio.run(create_admin(sys.argv[2], sys.argv[3], sys.argv[4]))
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
