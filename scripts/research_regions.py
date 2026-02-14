#!/usr/bin/env python3
"""農業地域の伝統作物・伝統料理リサーチ (Gemini / Claude API)

海外の農業地域プリセットごとに、伝統的な作物と料理を調査し、
Markdownファイルとして保存する。

Gemini Deep Research の手動調査を補完するための自動リサーチ。
出力は data/deep_research/農業地域/ に保存。

Usage:
    python scripts/research_regions.py --region italy          # イタリア全産地
    python scripts/research_regions.py --region france         # フランス
    python scripts/research_regions.py --region all            # 海外全産地
    python scripts/research_regions.py --only campania_agro    # 特定産地のみ
    python scripts/research_regions.py --only campania_agro --engine claude  # Claude使用
    python scripts/research_regions.py --list                  # 対象産地一覧
    python scripts/research_regions.py --force                 # 再生成
"""

import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "data" / "deep_research" / "農業地域"

# climate-server のプリセットを読み込む
sys.path.insert(0, str(ROOT / "climate-server"))
from services.era5_service import FARM_PRESETS

load_dotenv(ROOT / ".env")


# ── プロンプト ────────────────────────────────────────────────────

PROMPT_TEMPLATE = """\
「{name}」（{region_label}）の農業地域について、以下の内容を調査し、\
Markdownで詳しくまとめてください。

## 調査対象

**地域情報:**
- 緯度経度: ({lat}, {lon})
- タイムゾーン: {tz}
- 備考: {note}

## 書いてほしい内容

### 1. 地域の気候・土壌特性
- ケッペンの気候区分
- 年間降水量、年間平均気温の目安
- 農業に影響する気候の特徴（乾季・雨季、霜、風など）
- 土壌の特性（火山灰土、粘土質、砂質など）

### 2. 伝統作物・在来品種
- この地域で古くから栽培されている作物
- 在来品種（landrace）や伝統品種で、名前がわかるもの
- DOP/IGP/GI等の地理的表示認証を持つ農産物
- 種子の入手先（種苗会社、種子バンク、現地マーケットなど）

### 3. 伝統料理・食文化
- この地域の代表的な伝統料理（5〜10品）
- 各料理に使われる伝統的な食材
- 保存食の伝統（発酵、乾燥、漬物など）
- 季節ごとの食文化

### 4. 自然農法との親和性
- 有機農業・自然農法の取り組み（あれば）
- コンパニオンプランティングの伝統的な組み合わせ
- 伝統的な病害虫対策
- 輪作体系

### 5. 日本の自然農法実践者へのヒント
- 日本の気候との比較（類似点・相違点）
- この地域の伝統品種を日本で育てる場合の注意点
- 日本で入手可能な類似品種

## 注意事項
- 具体的な品種名やDOP/IGP認証名はイタリア語/現地語で正確に記載すること
- 推測ではなく、確実な情報のみを記載すること
- わからない点は「要調査」と明記すること
"""

# ── API クライアント ──────────────────────────────────────────────


def get_gemini_client():
    """Vertex AI / Gemini API クライアント"""
    from google import genai

    project = os.environ.get("GOOGLE_CLOUD_PROJECT")
    location = os.environ.get("GOOGLE_CLOUD_LOCATION", "global")

    if project:
        print(f"Gemini (Vertex AI: {project} / {location})")
        return genai.Client(vertexai=True, project=project, location=location)

    api_key = os.environ.get("GOOGLE_API_KEY")
    if api_key:
        print("Gemini (API key)")
        return genai.Client(api_key=api_key)

    return None


def generate_gemini(client, prompt: str) -> str:
    """Gemini API で生成"""
    from google.genai.types import GenerateContentConfig

    model = os.environ.get("GEMINI_MODEL", "gemini-3-pro-preview")
    config = GenerateContentConfig(temperature=0.5)
    response = client.models.generate_content(
        model=model, contents=prompt, config=config,
    )
    return response.text or ""


def generate_claude(prompt: str) -> str:
    """Claude API で生成"""
    import anthropic

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("ANTHROPIC_API_KEY が未設定です")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-sonnet-4-5-20250929",
        max_tokens=8192,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


# ── リトライ付き生成 ─────────────────────────────────────────────

MAX_RETRIES = 3
RETRY_DELAYS = [10, 30, 60]


def generate_with_retry(engine: str, gemini_client, prompt: str) -> str | None:
    """リトライ付きでテキスト生成"""
    for attempt in range(MAX_RETRIES):
        try:
            if engine == "gemini":
                return generate_gemini(gemini_client, prompt)
            else:
                return generate_claude(prompt)

        except Exception as e:
            err = str(e)
            if attempt < MAX_RETRIES - 1:
                delay = RETRY_DELAYS[attempt]
                print(f"    エラー: {err[:100]} — {delay}秒後にリトライ ({attempt + 1}/{MAX_RETRIES})")
                time.sleep(delay)
            else:
                print(f"    {MAX_RETRIES}回リトライ後も失敗: {err[:200]}")
                return None

    return None


# ── メイン ────────────────────────────────────────────────────────

def region_label(preset: dict) -> str:
    """地域の表示ラベル"""
    region = preset.get("region", "")
    labels = {
        "japan": "日本", "italy": "イタリア", "france": "フランス",
        "usa": "アメリカ", "southeast_asia": "東南アジア", "australia": "オーストラリア",
    }
    return labels.get(region, region)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="農業地域の伝統作物・料理リサーチ")
    parser.add_argument(
        "--region", default="all_overseas",
        help="japan / italy / france / usa / southeast_asia / australia / all / all_overseas [default: all_overseas]",
    )
    parser.add_argument("--only", help="特定プリセットのみ (カンマ区切り)")
    parser.add_argument("--engine", default="gemini", help="gemini / claude [default: gemini]")
    parser.add_argument("--force", action="store_true", help="既存ファイルを上書き")
    parser.add_argument("--list", action="store_true", help="対象一覧のみ表示")
    args = parser.parse_args()

    # 対象フィルタ
    if args.only:
        only_keys = [k.strip() for k in args.only.split(",")]
        targets = {k: v for k, v in FARM_PRESETS.items() if k in only_keys}
    elif args.region == "all":
        targets = FARM_PRESETS
    elif args.region == "all_overseas":
        targets = {k: v for k, v in FARM_PRESETS.items() if v.get("region") != "japan"}
    else:
        targets = {k: v for k, v in FARM_PRESETS.items() if v.get("region") == args.region}

    if not targets:
        regions = sorted(set(v.get("region", "") for v in FARM_PRESETS.values()))
        print(f"対象なし。--region の候補: {regions}")
        sys.exit(1)

    # 一覧表示モード
    if args.list:
        print(f"対象農業地域: {len(targets)} 件\n")
        for key, preset in targets.items():
            out_path = OUT_DIR / f"{key}.md"
            status = "生成済み" if out_path.exists() else "未生成"
            print(f"  {key:25s}  {preset['name']:15s}  [{preset.get('region', '')}]  {status}")
        return

    # API クライアント
    gemini_client = None
    if args.engine == "gemini":
        gemini_client = get_gemini_client()
        if not gemini_client:
            print("Gemini の認証情報がありません。--engine claude を試すか、")
            print("  GOOGLE_API_KEY または GOOGLE_CLOUD_PROJECT を設定してください。")
            sys.exit(1)
    else:
        # Claude は generate_claude() 内でクライアント作成
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            print("ANTHROPIC_API_KEY が未設定です。")
            sys.exit(1)
        print(f"Claude API")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\n農業地域リサーチ: {len(targets)} 地域")
    print(f"エンジン: {args.engine}")
    print(f"出力先: {OUT_DIR.relative_to(ROOT)}/\n")

    ok = 0
    skip = 0
    fail = 0

    for i, (key, preset) in enumerate(targets.items(), 1):
        out_path = OUT_DIR / f"{key}.md"

        # 既存スキップ
        if out_path.exists() and not args.force:
            print(f"[{i}/{len(targets)}] {key}: 既に存在 (--force で再生成)")
            skip += 1
            continue

        print(f"[{i}/{len(targets)}] {key}: {preset['name']} ...", end=" ", flush=True)

        prompt = PROMPT_TEMPLATE.format(
            name=preset["name"],
            region_label=region_label(preset),
            lat=preset["lat"],
            lon=preset["lon"],
            tz=preset["tz"],
            note=preset.get("note", ""),
        )

        result = generate_with_retry(args.engine, gemini_client, prompt)

        if result and result.strip():
            # ヘッダー追加
            header = f"# {preset['name']}（{region_label(preset)}）\n\n"
            header += f"*座標: ({preset['lat']}, {preset['lon']}) — {preset.get('note', '')}*\n\n"
            content = header + result

            out_path.write_text(content, encoding="utf-8")
            print(f"{len(content):,} chars")
            ok += 1
        else:
            print("失敗")
            fail += 1

        # レート制限対策
        if i < len(targets):
            time.sleep(2)

    print(f"\n完了: 成功 {ok}, スキップ {skip}, 失敗 {fail}")
    print(f"出力: {OUT_DIR}/")


if __name__ == "__main__":
    main()
