#!/usr/bin/env python3
"""農業地域プリセットの気候データを一括取得。

Open-Meteo Historical API (ERA5 0.25°) から daily データを取得し、
NetCDF ファイルに保存する。農地の気候特性を把握するための過去データ蓄積。

デフォルト5年分: 品種選択・播種時期・栽培計画に必要な長期気候パターンを収集。

Usage:
    cd climate-server
    python scripts/collect_presets.py                          # 日本 (過去5年)
    python scripts/collect_presets.py --years 10               # 過去10年
    python scripts/collect_presets.py --region all             # 全地域
    python scripts/collect_presets.py --region italy --start 2020-01-01
    python scripts/collect_presets.py --only tokachi_plain,echigo_uonuma
    python scripts/collect_presets.py --force                  # 既存データも再取得
"""

import asyncio
import logging
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

# climate-server をモジュール検索パスに追加
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from services.era5_service import FARM_PRESETS, fetch_daily_open_meteo
from storage import netcdf_store

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("collect_presets")

# ── 設定 ────────────────────────────────────────────────────────────

MAX_RETRIES = 3
RETRY_DELAYS = [5, 15, 30]          # 秒
REQUEST_INTERVAL = 1.5               # API 呼び出し間隔 (秒)


def loc_key(lat: float, lon: float) -> str:
    return f"{lat:.2f}_{lon:.2f}"


async def collect_one(
    key: str, preset: dict,
    date_start: str, date_end: str,
    force: bool = False,
) -> str:
    """1 プリセットのデータを取得・保存。

    Returns: "ok" / "skip" / "error"
    """
    lat, lon = preset["lat"], preset["lon"]
    lk = loc_key(lat, lon)

    # 既存データ確認
    if not force:
        existing = netcdf_store.load(lk)
        if existing is not None:
            return "skip"

    for attempt in range(MAX_RETRIES):
        try:
            ds = await fetch_daily_open_meteo(lat, lon, date_start, date_end)
            new_days = netcdf_store.save_daily(lk, lat, lon, ds)
            logger.info(
                "%s (%s) — %d days, %d new",
                preset["name"], lk, len(ds.time), new_days,
            )
            return "ok"

        except Exception as e:
            err = str(e)
            if attempt < MAX_RETRIES - 1:
                delay = RETRY_DELAYS[attempt]
                logger.warning(
                    "%s: %s — %d秒後にリトライ (%d/%d)",
                    key, err[:120], delay, attempt + 1, MAX_RETRIES,
                )
                time.sleep(delay)
            else:
                logger.error("%s: %d回リトライ後も失敗 — %s", key, MAX_RETRIES, err[:200])
                return "error"

    return "error"


async def main():
    import argparse

    parser = argparse.ArgumentParser(description="農業地域プリセットの気候データ一括取得")
    parser.add_argument(
        "--region", default="japan",
        help="地域 (japan/italy/france/usa/southeast_asia/australia/all) [default: japan]",
    )
    parser.add_argument(
        "--years", type=int, default=5,
        help="過去N年分を取得 [default: 5]",
    )
    parser.add_argument(
        "--start",
        help="開始日 YYYY-MM-DD (指定時は --years を無視)",
    )
    parser.add_argument(
        "--end",
        help="終了日 YYYY-MM-DD [default: 昨日]",
    )
    parser.add_argument(
        "--only",
        help="指定プリセットのみ (カンマ区切り: tokachi_plain,echigo_uonuma)",
    )
    parser.add_argument(
        "--force", action="store_true",
        help="既存データがあっても再取得",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="対象一覧のみ表示 (実際には取得しない)",
    )
    args = parser.parse_args()

    # 日付デフォルト (農地気候: 長期パターン把握のため5年以上推奨)
    yesterday = datetime.utcnow() - timedelta(days=1)
    n_years_ago = yesterday - timedelta(days=365 * args.years)
    date_start = args.start or n_years_ago.strftime("%Y-%m-%d")
    date_end = args.end or yesterday.strftime("%Y-%m-%d")

    # 対象フィルタ
    if args.only:
        only_keys = [k.strip() for k in args.only.split(",")]
        targets = {k: v for k, v in FARM_PRESETS.items() if k in only_keys}
        missing = set(only_keys) - set(targets.keys())
        if missing:
            logger.warning("見つからないプリセット: %s", missing)
    elif args.region == "all":
        targets = FARM_PRESETS
    else:
        targets = {k: v for k, v in FARM_PRESETS.items() if v.get("region") == args.region}

    if not targets:
        regions = sorted(set(v.get("region", "") for v in FARM_PRESETS.values()))
        print(f"対象プリセットなし。--region の候補: {regions}")
        sys.exit(1)

    # data ディレクトリ
    data_dir = ROOT / "data"
    data_dir.mkdir(parents=True, exist_ok=True)

    print(f"農地気候データ一括取得")
    print(f"  期間: {date_start} ～ {date_end}")
    print(f"  対象: {len(targets)} プリセット ({args.region})")
    print(f"  保存: {data_dir.resolve()}")
    print(f"  ソース: Open-Meteo Historical API (ERA5 0.25°)")
    print()

    if args.dry_run:
        for key, preset in targets.items():
            lk = loc_key(preset["lat"], preset["lon"])
            existing = netcdf_store.load(lk)
            status = "保存済み" if existing else "未取得"
            print(f"  {key:25s}  {preset['name']:12s}  ({preset['lat']:7.2f}, {preset['lon']:7.2f})  {status}")
        return

    # 取得実行
    ok = 0
    skip = 0
    fail = 0

    for key, preset in targets.items():
        result = await collect_one(key, preset, date_start, date_end, force=args.force)

        if result == "ok":
            print(f"  + {key}: {preset['name']}")
            ok += 1
        elif result == "skip":
            print(f"  - {key}: 既に保存済み (--force で再取得)")
            skip += 1
        else:
            print(f"  x {key}: 失敗")
            fail += 1

        # レート制限対策
        if result != "skip":
            time.sleep(REQUEST_INTERVAL)

    print(f"\n完了: 成功 {ok}, スキップ {skip}, 失敗 {fail}")


if __name__ == "__main__":
    asyncio.run(main())
