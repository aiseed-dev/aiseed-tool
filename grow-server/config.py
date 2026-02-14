import secrets

from pydantic_settings import BaseSettings
from pathlib import Path


def _ensure_secret_key(env_path: Path) -> str:
    """SECRET_KEY が未設定なら自動生成して .env に書き込む。"""
    sentinel = "change-me-in-production"
    key_prefix = "GROW_GPU_SECRET_KEY="

    # .env が存在しなければ作成
    if not env_path.exists():
        key = secrets.token_urlsafe(32)
        env_path.write_text(f"{key_prefix}{key}\n")
        return key

    lines = env_path.read_text().splitlines()

    # 既存の SECRET_KEY を探す
    for i, line in enumerate(lines):
        if line.startswith(key_prefix):
            value = line[len(key_prefix):]
            if value and value != sentinel and value != "your-secret-key-here":
                return value
            # デフォルト値のまま → 生成して上書き
            key = secrets.token_urlsafe(32)
            lines[i] = f"{key_prefix}{key}"
            env_path.write_text("\n".join(lines) + "\n")
            return key

    # SECRET_KEY の行がない → 追記
    key = secrets.token_urlsafe(32)
    lines.append(f"{key_prefix}{key}")
    env_path.write_text("\n".join(lines) + "\n")
    return key


_env_path = Path(__file__).parent / ".env"
_auto_secret = _ensure_secret_key(_env_path)


class Settings(BaseSettings):
    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Database
    database_url: str = "sqlite+aiosqlite:///./grow_gpu.db"

    # Auth
    secret_key: str = _auto_secret
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 30  # 30 days

    # Social Auth
    apple_client_id: str = ""   # Apple Services ID (e.g., dev.aiseed.grow)
    google_client_id: str = ""  # Google OAuth 2.0 Client ID

    # GPU Models
    ocr_languages: list[str] = ["japan", "en", "it"]
    florence_model: str = "microsoft/Florence-2-base"

    # Upload
    upload_dir: str = "./uploads"
    max_upload_size: int = 20 * 1024 * 1024  # 20MB

    # AMeDAS 定期取得（カンマ区切りの地点ID、最大3箇所）
    amedas_stations: str = ""  # 例: "44132,44171,44191"

    # Mail（Postfix + DKIM）
    mail_from: str = "noreply@aiseed.dev"

    model_config = {"env_prefix": "GROW_GPU_", "env_file": ".env"}


settings = Settings()

# Ensure upload dir exists
Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
