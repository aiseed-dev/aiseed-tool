import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

AUTH_TOKEN: str = os.getenv("AUTH_TOKEN", "")
ANTHROPIC_KEY: str = os.getenv("ANTHROPIC_KEY", "")
PHOTOS_DIR: Path = Path(os.getenv("PHOTOS_DIR", "./photos"))
PORT: int = int(os.getenv("PORT", "8000"))

# Ensure photos directory exists
PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
