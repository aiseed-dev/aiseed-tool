from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Database
    database_url: str = "sqlite+aiosqlite:///./grow_gpu.db"

    # Auth
    secret_key: str = "change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 30  # 30 days

    # Social Auth
    apple_client_id: str = ""   # Apple Services ID (e.g., dev.aiseed.grow)
    google_client_id: str = ""  # Google OAuth 2.0 Client ID

    # AI (Claude API)
    anthropic_api_key: str = ""
    ai_model: str = "claude-haiku-4-5-20251001"

    # GPU Models
    ocr_languages: list[str] = ["japan", "en", "it"]
    florence_model: str = "microsoft/Florence-2-base"

    # Upload
    upload_dir: str = "./uploads"
    max_upload_size: int = 20 * 1024 * 1024  # 20MB

    model_config = {"env_prefix": "GROW_GPU_", "env_file": ".env"}


settings = Settings()

# Ensure upload dir exists
Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
