"""データ同期エンドポイント（デスクトップ版）

Cloudflare Workers 版と同じ API 仕様:
  POST /sync/pull  - 更新データの取得
  POST /sync/push  - 更新データの送信

デスクトップ版では SQLite をバックエンドに使用。
"""

import sqlite3
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from .auth import verify_token
from . import config

router = APIRouter()

SYNC_TABLES = [
    "locations",
    "plots",
    "crops",
    "records",
    "record_photos",
    "observations",
    "observation_entries",
]

DB_PATH = config.PHOTOS_DIR.parent / "grow-sync.db"


def _get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    _ensure_schema(conn)
    return conn


def _ensure_schema(conn: sqlite3.Connection) -> None:
    """Create tables if they don't exist (same as server/schema.sql)."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS locations (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            environment_type INTEGER NOT NULL DEFAULT 0,
            latitude REAL,
            longitude REAL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS plots (
            id TEXT PRIMARY KEY,
            location_id TEXT NOT NULL,
            name TEXT NOT NULL,
            cover_type INTEGER NOT NULL DEFAULT 0,
            soil_type INTEGER NOT NULL DEFAULT 0,
            memo TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS crops (
            id TEXT PRIMARY KEY,
            cultivation_name TEXT NOT NULL DEFAULT '',
            name TEXT NOT NULL DEFAULT '',
            variety TEXT NOT NULL DEFAULT '',
            plot_id TEXT,
            parent_crop_id TEXT,
            memo TEXT NOT NULL DEFAULT '',
            start_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS records (
            id TEXT PRIMARY KEY,
            crop_id TEXT,
            location_id TEXT,
            plot_id TEXT,
            activity_type INTEGER NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS record_photos (
            id TEXT PRIMARY KEY,
            record_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            r2_key TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS observations (
            id TEXT PRIMARY KEY,
            location_id TEXT,
            plot_id TEXT,
            category INTEGER NOT NULL DEFAULT 0,
            date TEXT NOT NULL,
            memo TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS observation_entries (
            id TEXT PRIMARY KEY,
            observation_id TEXT NOT NULL,
            key TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS deleted_records (
            id TEXT NOT NULL,
            table_name TEXT NOT NULL,
            deleted_at TEXT NOT NULL,
            PRIMARY KEY (id, table_name)
        );
    """)


class PullRequest(BaseModel):
    since: str = "1970-01-01T00:00:00.000Z"


class DeletedItem(BaseModel):
    id: str
    table_name: str


class PushRequest(BaseModel):
    locations: list[dict] = []
    plots: list[dict] = []
    crops: list[dict] = []
    records: list[dict] = []
    record_photos: list[dict] = []
    observations: list[dict] = []
    observation_entries: list[dict] = []
    deleted: list[DeletedItem] = []


@router.post("/sync/pull")
async def sync_pull(
    body: PullRequest,
    _: None = Depends(verify_token),
):
    conn = _get_db()
    now = datetime.now(timezone.utc).isoformat()
    result: dict = {}

    try:
        for table in SYNC_TABLES:
            rows = conn.execute(
                f"SELECT * FROM {table} WHERE updated_at > ?",
                (body.since,),
            ).fetchall()
            result[table] = [dict(r) for r in rows]

        deleted = conn.execute(
            "SELECT id, table_name, deleted_at FROM deleted_records WHERE deleted_at > ?",
            (body.since,),
        ).fetchall()
        result["deleted"] = [dict(r) for r in deleted]
        result["timestamp"] = now
    finally:
        conn.close()

    return result


@router.post("/sync/push")
async def sync_push(
    body: PushRequest,
    _: None = Depends(verify_token),
):
    conn = _get_db()
    now = datetime.now(timezone.utc).isoformat()

    try:
        table_data = {
            "locations": body.locations,
            "plots": body.plots,
            "crops": body.crops,
            "records": body.records,
            "record_photos": body.record_photos,
            "observations": body.observations,
            "observation_entries": body.observation_entries,
        }

        for table, rows in table_data.items():
            for row in rows:
                columns = list(row.keys())
                placeholders = ", ".join(["?"] * len(columns))
                updates = ", ".join(
                    f"{c} = excluded.{c}" for c in columns if c != "id"
                )
                conn.execute(
                    f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({placeholders}) "
                    f"ON CONFLICT(id) DO UPDATE SET {updates}",
                    [row[c] for c in columns],
                )

        for item in body.deleted:
            if item.table_name not in SYNC_TABLES:
                continue
            conn.execute(
                f"DELETE FROM {item.table_name} WHERE id = ?", (item.id,)
            )
            conn.execute(
                "INSERT INTO deleted_records (id, table_name, deleted_at) VALUES (?, ?, ?) "
                "ON CONFLICT(id, table_name) DO UPDATE SET deleted_at = excluded.deleted_at",
                (item.id, item.table_name, now),
            )

        conn.commit()
    finally:
        conn.close()

    return {"ok": True, "timestamp": now}
