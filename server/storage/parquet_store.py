"""Parquet ファイルベースの時系列ストレージ。

月次 Parquet ファイル（YYYY-MM.parquet）で管理する。
Ecowitt / AMeDAS の観測データに使用。

ディレクトリ構成:
    data/ecowitt/YYYY-MM.parquet
    data/amedas/{station_id}/YYYY-MM.parquet
"""

import logging
from datetime import datetime
from pathlib import Path

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

logger = logging.getLogger(__name__)


def _month_key(dt: datetime) -> str:
    """datetime → 'YYYY-MM' 文字列"""
    return dt.strftime("%Y-%m")


def _parquet_path(base_dir: Path, month_key: str) -> Path:
    return base_dir / f"{month_key}.parquet"


def append_records(base_dir: Path, records: list[dict]) -> int:
    """レコードを月次 Parquet に追記する。

    records 内の 'recorded_at' / 'observed_at' カラムから月を判定。
    戻り値: 追記したレコード数。
    """
    if not records:
        return 0

    base_dir.mkdir(parents=True, exist_ok=True)
    df_new = pd.DataFrame(records)

    # 時刻カラムを特定
    time_col = None
    for col in ("recorded_at", "observed_at", "time"):
        if col in df_new.columns:
            time_col = col
            break
    if time_col is None:
        raise ValueError("時刻カラムが見つかりません")

    df_new[time_col] = pd.to_datetime(df_new[time_col], utc=True)

    # 月ごとに分割して書き込み
    total = 0
    for month_key, group in df_new.groupby(df_new[time_col].dt.to_period("M")):
        path = _parquet_path(base_dir, str(month_key))

        if path.exists():
            df_existing = pd.read_parquet(path)
            df_existing[time_col] = pd.to_datetime(df_existing[time_col], utc=True)
            # 重複除去（時刻ベース）
            existing_times = set(df_existing[time_col])
            df_append = group[~group[time_col].isin(existing_times)]
            if df_append.empty:
                continue
            df_merged = pd.concat([df_existing, df_append], ignore_index=True)
        else:
            df_merged = group

        df_merged = df_merged.sort_values(time_col).reset_index(drop=True)
        df_merged.to_parquet(path, index=False)
        total += len(group)

    return total


def read_recent(base_dir: Path, time_col: str, hours: int = 24, limit: int = 100) -> pd.DataFrame:
    """直近 N 時間のレコードを読む。"""
    if not base_dir.exists():
        return pd.DataFrame()

    now = pd.Timestamp.now(tz="UTC")
    since = now - pd.Timedelta(hours=hours)

    # 対象の月ファイルを特定
    months = set()
    current = since
    while current <= now:
        months.add(_month_key(current.to_pydatetime()))
        current += pd.Timedelta(days=28)
    months.add(_month_key(now.to_pydatetime()))

    frames = []
    for mk in sorted(months):
        path = _parquet_path(base_dir, mk)
        if path.exists():
            frames.append(pd.read_parquet(path))

    if not frames:
        return pd.DataFrame()

    df = pd.concat(frames, ignore_index=True)
    df[time_col] = pd.to_datetime(df[time_col], utc=True)
    df = df[df[time_col] >= since].sort_values(time_col, ascending=False)
    return df.head(limit)


def read_range(base_dir: Path, time_col: str, start: datetime, end: datetime) -> pd.DataFrame:
    """指定期間のレコードを読む。"""
    if not base_dir.exists():
        return pd.DataFrame()

    start_ts = pd.Timestamp(start, tz="UTC")
    end_ts = pd.Timestamp(end, tz="UTC")

    # 対象の月ファイル
    months = set()
    current = start_ts
    while current <= end_ts:
        months.add(_month_key(current.to_pydatetime()))
        current += pd.Timedelta(days=28)
    months.add(_month_key(end_ts.to_pydatetime()))

    frames = []
    for mk in sorted(months):
        path = _parquet_path(base_dir, mk)
        if path.exists():
            frames.append(pd.read_parquet(path))

    if not frames:
        return pd.DataFrame()

    df = pd.concat(frames, ignore_index=True)
    df[time_col] = pd.to_datetime(df[time_col], utc=True)
    df = df[(df[time_col] >= start_ts) & (df[time_col] <= end_ts)]
    return df.sort_values(time_col).reset_index(drop=True)


def read_latest(base_dir: Path, time_col: str) -> dict | None:
    """最新の1レコードを返す。"""
    if not base_dir.exists():
        return None

    # 最新の Parquet ファイルを探す
    files = sorted(base_dir.glob("*.parquet"), reverse=True)
    for path in files:
        df = pd.read_parquet(path)
        if df.empty:
            continue
        df[time_col] = pd.to_datetime(df[time_col], utc=True)
        df = df.sort_values(time_col, ascending=False)
        return df.iloc[0].to_dict()

    return None


def list_parquet_files(base_dir: Path) -> list[str]:
    """保存されている月ファイル一覧。"""
    if not base_dir.exists():
        return []
    return sorted(p.stem for p in base_dir.glob("*.parquet"))
