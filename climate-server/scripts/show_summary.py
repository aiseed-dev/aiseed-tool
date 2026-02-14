#!/usr/bin/env python3
"""保存済み気候データのサマリー表示。

NetCDF ファイルの中身を一覧表示する。
プリセットとの突合も行い、未取得の産地を表示する。

Usage:
    cd climate-server
    python scripts/show_summary.py              # 保存済みデータ一覧
    python scripts/show_summary.py --missing    # 未取得プリセット一覧
    python scripts/show_summary.py --detail     # 変数・日数の詳細
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from services.era5_service import FARM_PRESETS
from storage import netcdf_store


def loc_key(lat: float, lon: float) -> str:
    return f"{lat:.2f}_{lon:.2f}"


def main():
    import argparse

    parser = argparse.ArgumentParser(description="保存済み気候データのサマリー")
    parser.add_argument("--missing", action="store_true", help="未取得プリセットのみ表示")
    parser.add_argument("--detail", action="store_true", help="変数一覧も表示")
    args = parser.parse_args()

    data_dir = ROOT / "data"
    if not data_dir.exists():
        print(f"データディレクトリなし: {data_dir}")
        return

    # 保存済みファイル一覧
    stored = netcdf_store.list_locations()

    # プリセットキーのマッピング
    preset_by_lk = {}
    for key, preset in FARM_PRESETS.items():
        lk = loc_key(preset["lat"], preset["lon"])
        preset_by_lk[lk] = (key, preset)

    if args.missing:
        print("未取得プリセット:")
        print()
        count = 0
        for key, preset in FARM_PRESETS.items():
            lk = loc_key(preset["lat"], preset["lon"])
            if lk not in stored:
                print(f"  {key:25s}  {preset['name']:15s}  ({preset['lat']:7.2f}, {preset['lon']:7.2f})  [{preset.get('region', '')}]")
                count += 1
        if count == 0:
            print("  全プリセット取得済み")
        else:
            print(f"\n  未取得: {count} / {len(FARM_PRESETS)}")
        return

    # 保存済みデータ一覧
    print(f"保存済み気候データ ({len(stored)} 地点)")
    print(f"データディレクトリ: {data_dir.resolve()}")
    print()

    total_days = 0
    for lk in sorted(stored):
        info = netcdf_store.summary(lk)
        if not info:
            continue

        # プリセット名があれば表示
        preset_info = preset_by_lk.get(lk)
        label = f"  {preset_info[0]}" if preset_info else ""

        days = info["total_days"]
        total_days += days
        print(
            f"  {lk:15s}  {info['date_start']} ～ {info['date_end']}  "
            f"{days:5d} days  {len(info['variables']):2d} vars{label}"
        )

        if args.detail:
            for var in sorted(info["variables"]):
                print(f"    - {var}")
            print()

    print(f"\n合計: {len(stored)} 地点, {total_days:,} 日分")

    # プリセットカバー率
    covered = sum(1 for key, p in FARM_PRESETS.items() if loc_key(p["lat"], p["lon"]) in stored)
    print(f"プリセット: {covered} / {len(FARM_PRESETS)} 取得済み")


if __name__ == "__main__":
    main()
