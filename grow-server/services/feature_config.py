"""ユーザー別機能許可設定（users.yaml）。

admin / super_user / pending はロールで固定。
role=user のみ users.yaml で機能を制御する。
"""

import logging
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

_CONFIG_PATH = Path(__file__).parent.parent / "users.yaml"
_user_features: dict[str, list[str]] = {}

# 全機能名
ALL_FEATURES = [
    "ai", "ocr", "vision", "grow", "site",
    "fude", "qr", "consumer", "skillfile",
]


def load_user_features(path: Path | None = None) -> dict[str, list[str]]:
    """users.yaml を読み込んでキャッシュ。"""
    global _user_features
    p = path or _CONFIG_PATH

    if not p.exists():
        logger.warning("users.yaml が見つかりません: %s", p)
        _user_features = {}
        return _user_features

    try:
        data: dict[str, Any] = yaml.safe_load(p.read_text("utf-8")) or {}
        users = data.get("users") or {}
        _user_features = {}
        for username, conf in users.items():
            if isinstance(conf, dict):
                features = conf.get("features", [])
                _user_features[username] = [f for f in features if f in ALL_FEATURES]
        logger.info("users.yaml 読み込み: %d ユーザー設定", len(_user_features))
    except Exception as e:
        logger.error("users.yaml 読み込みエラー: %s", e)
        _user_features = {}

    return _user_features


def get_user_features(username: str) -> list[str] | None:
    """ユーザーの許可機能リストを返す。設定なしなら None。"""
    return _user_features.get(username)


def reload():
    """設定を再読み込み。"""
    load_user_features()
