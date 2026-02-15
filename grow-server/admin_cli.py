"""管理CLIツール — ユーザー管理をコマンドラインで行う。

Usage:
    python admin_cli.py list                    # 全ユーザー一覧
    python admin_cli.py pending                 # 承認待ち一覧
    python admin_cli.py approve <username>      # ユーザーを承認（→ user）
    python admin_cli.py set-super <username>    # super_user に昇格
    python admin_cli.py set-admin <username>    # admin に昇格
    python admin_cli.py set-role <username> <role>  # ロール直接指定
    python admin_cli.py deactivate <username>   # ユーザーを無効化
    python admin_cli.py activate <username>     # ユーザーを有効化
    python admin_cli.py create-admin <user> <email> <pass>  # 初期管理者作成
    python admin_cli.py features <username>     # ユーザーの許可機能を表示

ロール:
    admin      — 全機能 + ユーザー管理
    super_user — 管理以外すべて
    user       — users.yaml で許可された機能のみ
    pending    — プロフィールのみ
"""

import asyncio
import sys

from sqlalchemy import select
from database import async_session, init_db
from models.user import User, ROLE_PENDING, ROLE_USER, ROLE_SUPER_USER, ROLE_ADMIN
from services.auth_service import hash_password
from uuid import uuid4

VALID_ROLES = (ROLE_PENDING, ROLE_USER, ROLE_SUPER_USER, ROLE_ADMIN)


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

    print(f"{'username':<20} {'role':<12} {'active':<8} {'provider':<10} {'email'}")
    print("-" * 80)
    for u in users:
        role = getattr(u, "role", "pending")
        print(f"{u.username:<20} {role:<12} {'○' if u.is_active else '×':<8} {u.auth_provider:<10} {u.email}")
    print(f"\n合計: {len(users)} 件")


async def set_role(username: str, role: str):
    """ユーザーのロールを変更。"""
    if role not in VALID_ROLES:
        print(f"エラー: 無効なロール '{role}'（{', '.join(VALID_ROLES)}）")
        return
    async with async_session() as db:
        user = await _find_user(db, username)
        if not user:
            return
        old_role = getattr(user, "role", "pending")
        user.role = role
        if role != ROLE_PENDING:
            user.is_active = True
        await db.commit()
        print(f"ロール変更: {username} {old_role} → {role}")


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


async def show_features(username: str):
    """ユーザーの利用可能機能を表示。"""
    from services.feature_config import load_user_features, get_user_features, ALL_FEATURES
    load_user_features()

    async with async_session() as db:
        user = await _find_user(db, username)
        if not user:
            return

    role = getattr(user, "role", "pending")
    print(f"ユーザー: {username}")
    print(f"ロール:   {role}")

    if role == ROLE_ADMIN:
        print("機能:     全機能 + 管理")
    elif role == ROLE_SUPER_USER:
        print("機能:     管理以外すべて")
    elif role == ROLE_PENDING:
        print("機能:     プロフィールのみ")
    else:
        allowed = get_user_features(username)
        if allowed:
            print(f"機能:     {', '.join(allowed)}")
        else:
            print("機能:     未設定（users.yaml に追加してください）")
        print(f"全機能:   {', '.join(ALL_FEATURES)}")


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
        asyncio.run(set_role(sys.argv[2], ROLE_USER))
    elif cmd == "set-super" and len(sys.argv) >= 3:
        asyncio.run(set_role(sys.argv[2], ROLE_SUPER_USER))
    elif cmd == "set-admin" and len(sys.argv) >= 3:
        asyncio.run(set_role(sys.argv[2], ROLE_ADMIN))
    elif cmd == "set-role" and len(sys.argv) >= 4:
        asyncio.run(set_role(sys.argv[2], sys.argv[3]))
    elif cmd == "deactivate" and len(sys.argv) >= 3:
        asyncio.run(deactivate_user(sys.argv[2]))
    elif cmd == "activate" and len(sys.argv) >= 3:
        asyncio.run(activate_user(sys.argv[2]))
    elif cmd == "create-admin" and len(sys.argv) >= 5:
        asyncio.run(create_admin(sys.argv[2], sys.argv[3], sys.argv[4]))
    elif cmd == "features" and len(sys.argv) >= 3:
        asyncio.run(show_features(sys.argv[2]))
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
