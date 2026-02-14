#!/usr/bin/env python3
"""農地気候統計の算出。

保存済み NetCDF データから、農業判断に必要な気候統計を算出する。
品種選択・播種時期・栽培計画の基礎データ。

算出項目:
  - 月別平均気温（最高・最低・平均）
  - 月別降水量
  - 月別日射量
  - 積算温度（GDD: Growing Degree Days）
  - 霜日数（最低気温 < 0°C）
  - 初霜・終霜日（平年値）
  - 年間統計（平均気温、年間降水量）

Usage:
    cd climate-server
    python scripts/climate_stats.py --only tokachi_plain       # 1産地
    python scripts/climate_stats.py --region japan             # 日本全産地
    python scripts/climate_stats.py --region all --csv         # CSV出力
    python scripts/climate_stats.py --only echigo_uonuma --detail  # 月別詳細
"""

import csv as csv_mod
import io
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from services.era5_service import FARM_PRESETS
from storage import netcdf_store


def loc_key(lat: float, lon: float) -> str:
    return f"{lat:.2f}_{lon:.2f}"


def compute_stats(ds) -> dict | None:
    """NetCDF Dataset から農業気候統計を算出。"""
    times = pd.DatetimeIndex(ds.time.values)
    if len(times) < 30:
        return None

    result = {
        "period": f"{times.min().date()} ～ {times.max().date()}",
        "total_days": len(times),
        "years": round((times.max() - times.min()).days / 365.25, 1),
    }

    # ── 年間統計 ──────────────────────────────────────────
    if "temp_mean" in ds:
        vals = ds["temp_mean"].values
        valid = vals[~np.isnan(vals)]
        if len(valid) > 0:
            result["annual_temp_mean"] = round(float(np.mean(valid)), 1)

    if "temp_max" in ds:
        vals = ds["temp_max"].values
        valid = vals[~np.isnan(vals)]
        if len(valid) > 0:
            result["annual_temp_max_mean"] = round(float(np.mean(valid)), 1)
            result["absolute_max"] = round(float(np.max(valid)), 1)

    if "temp_min" in ds:
        vals = ds["temp_min"].values
        valid = vals[~np.isnan(vals)]
        if len(valid) > 0:
            result["annual_temp_min_mean"] = round(float(np.mean(valid)), 1)
            result["absolute_min"] = round(float(np.min(valid)), 1)
            # 霜日数 (年平均)
            frost_days = np.sum(valid < 0)
            n_years = max(1, result["years"])
            result["frost_days_per_year"] = round(frost_days / n_years, 1)

    if "precipitation" in ds:
        vals = ds["precipitation"].values
        valid = vals[~np.isnan(vals)]
        if len(valid) > 0:
            n_years = max(1, result["years"])
            result["annual_precip_mm"] = round(float(np.sum(valid)) / n_years, 0)

    if "shortwave_radiation" in ds:
        vals = ds["shortwave_radiation"].values
        valid = vals[~np.isnan(vals)]
        if len(valid) > 0:
            result["annual_radiation_mean"] = round(float(np.mean(valid)), 1)

    # ── 積算温度 (GDD base 10°C) ─────────────────────────
    if "temp_mean" in ds:
        vals = ds["temp_mean"].values
        gdd_daily = np.where(np.isnan(vals), 0, np.maximum(vals - 10, 0))
        n_years = max(1, result["years"])
        result["gdd_base10_annual"] = round(float(np.sum(gdd_daily)) / n_years, 0)

    # ── 初霜・終霜（平年値） ─────────────────────────────
    if "temp_min" in ds:
        vals = ds["temp_min"].values
        doy = times.dayofyear
        frost_mask = vals < 0

        if np.any(frost_mask):
            frost_doys = doy[frost_mask]
            # 初霜: 7月以降で最も早い霜日 (DOY > 180)
            autumn_frost = frost_doys[frost_doys > 180]
            if len(autumn_frost) > 0:
                # 年ごとの初霜DOYの平均
                result["first_frost_doy"] = int(np.median(autumn_frost))

            # 終霜: 1-6月で最も遅い霜日 (DOY <= 180)
            spring_frost = frost_doys[frost_doys <= 180]
            if len(spring_frost) > 0:
                result["last_frost_doy"] = int(np.median(spring_frost))

    # ── 月別統計 ──────────────────────────────────────────
    monthly = []
    for month in range(1, 13):
        mask = times.month == month
        if not np.any(mask):
            monthly.append({"month": month})
            continue

        m = {"month": month}

        for var, stat in [
            ("temp_mean", "mean"), ("temp_max", "mean"), ("temp_min", "mean"),
            ("precipitation", "sum"), ("shortwave_radiation", "mean"),
        ]:
            if var in ds:
                vals = ds[var].values[mask]
                valid = vals[~np.isnan(vals)]
                if len(valid) > 0:
                    if stat == "sum":
                        # 月別合計の年平均
                        n_years = max(1, result["years"])
                        m[var] = round(float(np.sum(valid)) / n_years, 1)
                    else:
                        m[var] = round(float(np.mean(valid)), 1)

        monthly.append(m)

    result["monthly"] = monthly
    return result


def doy_to_date(doy: int) -> str:
    """DOY → 月/日 文字列"""
    from datetime import date
    d = date(2024, 1, 1) + pd.Timedelta(days=doy - 1)  # 2024 is leap year
    return f"{d.month}/{d.day}"


def print_stats(key: str, preset: dict, stats: dict, detail: bool = False):
    """統計を表示。"""
    print(f"\n{'=' * 60}")
    print(f"  {preset['name']}  ({key})")
    print(f"  ({preset['lat']}, {preset['lon']})  {preset.get('note', '')}")
    print(f"  期間: {stats['period']}  ({stats['years']}年, {stats['total_days']}日)")
    print(f"{'=' * 60}")

    # 年間統計
    print(f"\n  年間平均気温:   {stats.get('annual_temp_mean', '?'):>6}°C")
    print(f"  年最高平均:     {stats.get('annual_temp_max_mean', '?'):>6}°C  (極値: {stats.get('absolute_max', '?')}°C)")
    print(f"  年最低平均:     {stats.get('annual_temp_min_mean', '?'):>6}°C  (極値: {stats.get('absolute_min', '?')}°C)")
    print(f"  年間降水量:     {stats.get('annual_precip_mm', '?'):>6} mm")
    print(f"  日射量(日平均): {stats.get('annual_radiation_mean', '?'):>6} MJ/m²")
    print(f"  積算温度(GDD10):{stats.get('gdd_base10_annual', '?'):>6}°C·day")
    print(f"  霜日数(年平均): {stats.get('frost_days_per_year', '?'):>6} 日")

    first_frost = stats.get("first_frost_doy")
    last_frost = stats.get("last_frost_doy")
    if first_frost:
        print(f"  初霜(中央値):   {doy_to_date(first_frost):>6}")
    if last_frost:
        print(f"  終霜(中央値):   {doy_to_date(last_frost):>6}")
    if first_frost and last_frost:
        frost_free = first_frost - last_frost
        print(f"  無霜期間:       {frost_free:>6} 日")

    # 月別詳細
    if detail and "monthly" in stats:
        print(f"\n  {'月':>3}  {'平均':>6}  {'最高':>6}  {'最低':>6}  {'降水mm':>7}  {'日射MJ':>7}")
        print(f"  {'─' * 42}")
        for m in stats["monthly"]:
            mo = m["month"]
            t_mean = m.get("temp_mean", "")
            t_max = m.get("temp_max", "")
            t_min = m.get("temp_min", "")
            precip = m.get("precipitation", "")
            rad = m.get("shortwave_radiation", "")
            print(f"  {mo:>3}  {t_mean:>6}  {t_max:>6}  {t_min:>6}  {precip:>7}  {rad:>7}")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="農地気候統計の算出")
    parser.add_argument(
        "--region", default="japan",
        help="japan / italy / france / all [default: japan]",
    )
    parser.add_argument("--only", help="特定プリセット (カンマ区切り)")
    parser.add_argument("--detail", action="store_true", help="月別詳細を表示")
    parser.add_argument("--csv", action="store_true", help="年間統計をCSV出力")
    args = parser.parse_args()

    # 対象フィルタ
    if args.only:
        only_keys = [k.strip() for k in args.only.split(",")]
        targets = {k: v for k, v in FARM_PRESETS.items() if k in only_keys}
    elif args.region == "all":
        targets = FARM_PRESETS
    else:
        targets = {k: v for k, v in FARM_PRESETS.items() if v.get("region") == args.region}

    if not targets:
        print("対象なし")
        sys.exit(1)

    all_stats = []

    for key, preset in targets.items():
        lk = loc_key(preset["lat"], preset["lon"])
        ds = netcdf_store.load(lk)

        if ds is None:
            print(f"  {key}: データなし (collect_presets.py で先に取得してください)")
            continue

        stats = compute_stats(ds)
        if stats is None:
            print(f"  {key}: データ不足 ({len(ds.time)} 日)")
            continue

        if not args.csv:
            print_stats(key, preset, stats, detail=args.detail)

        all_stats.append({"key": key, "preset": preset, "stats": stats})

    # CSV出力
    if args.csv and all_stats:
        out = io.StringIO()
        writer = csv_mod.writer(out)
        writer.writerow([
            "key", "name", "lat", "lon", "region", "years",
            "temp_mean", "temp_max_mean", "temp_min_mean",
            "absolute_max", "absolute_min",
            "annual_precip_mm", "radiation_mean",
            "gdd_base10", "frost_days",
        ])
        for item in all_stats:
            s = item["stats"]
            p = item["preset"]
            writer.writerow([
                item["key"], p["name"], p["lat"], p["lon"],
                p.get("region", ""), s.get("years", ""),
                s.get("annual_temp_mean", ""),
                s.get("annual_temp_max_mean", ""),
                s.get("annual_temp_min_mean", ""),
                s.get("absolute_max", ""),
                s.get("absolute_min", ""),
                s.get("annual_precip_mm", ""),
                s.get("annual_radiation_mean", ""),
                s.get("gdd_base10_annual", ""),
                s.get("frost_days_per_year", ""),
            ])
        print(out.getvalue())

    if not args.csv:
        print(f"\n統計算出: {len(all_stats)} / {len(targets)} 産地")


if __name__ == "__main__":
    main()
