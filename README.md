# aiseed-tool

**AI x 自然栽培** -- 栽培から販売までを支えるツールと知識基盤

## 概要

自然栽培を「記録する・知る・届ける」ための Flutter アプリと、それを支える知識基盤のプロジェクトです。

栽培記録はもちろん、アルバム・販売用 Web ページ・動画の作成まで、栽培から販売までの流れをひとつのツールでカバーします。畑仕事で忙しい人でも最小限の手間で使えることを重視しています。アプリ内でどこまで作り、外部ツールをどう活用するかは機能ごとに検討していきます。

知識基盤には、イタリア・日本の伝統野菜と伝統料理のデータに加え、自然農法や土壌生物学の知識を収録。全文検索や AI による検索で、必要な情報にすぐアクセスできることを目指します。

除草するためではなく、共生するためのツールです。

## 特徴

- **栽培記録**: 日々の観察・作業をシンプルに記録
- **アルバム**: 家庭菜園の写真をアルバムにまとめる
- **販売Web作成**: 栽培した野菜の販売ページを生成
- **動画作成**: 栽培の様子や商品紹介の動画を作成
- **知識基盤**: 伝統野菜・伝統料理・自然農法・土壌生物学の構造化データ
- **AIチャット**: 知識基盤と自分の栽培記録をコンテキストにして AI に相談できる
- **情報検索**: 全文検索 + AI 検索で知識基盤から必要な情報を引き出す
- **マルチAIリサーチ**: Claude（深堀り調査）+ Gemini（バッチ処理）でデータを構築
- **多言語対応**: イタリア語・日本語・英語のソースを直接調査

## プロジェクト構成

```
aiseed-tool/
├── grow/                          # Flutter アプリ（記録・アルバム・販売Web・動画）
├── grow-server/                   # FastAPI バックエンド（データ同期・筆ポリゴン）
├── climate-server/                # 気候データサーバー（ERA5・AgERA5・世界時計）
│   ├── services/                  # データ取得サービス
│   │   ├── era5_service.py        #   農地気候 (Open-Meteo ERA5 0.25°)
│   │   ├── agera5_gee.py          #   AgERA5 via Google Earth Engine (0.1°)
│   │   ├── era5_s3.py             #   世界時計 (AWS S3 ERA5 minmax/accumu)
│   │   ├── fude_grid.py           #   筆ポリゴン → AgERA5グリッドマッピング
│   │   └── sentinel2.py           #   Sentinel-2 植生指数（予定）
│   ├── routers/                   # API エンドポイント
│   │   ├── era5.py                #   /era5/* 農地気候
│   │   └── world_clock.py         #   /world-clock/* 旅行・都市比較
│   ├── storage/                   # NetCDF 日次データストレージ
│   └── scripts/                   # データ収集・統計スクリプト
│       ├── collect_presets.py     #   農地気候の一括取得（10年/30年）
│       ├── climate_stats.py       #   気候統計・特異現象の算出
│       └── show_summary.py        #   保存状況の確認
├── data/
│   ├── vegetables/                # 伝統野菜データ (JSON)
│   ├── recipes/                   # 伝統料理データ (JSON)
│   ├── master_lists/              # マスターデータ (CSV)
│   └── deep_research/             # 深堀り調査結果 (Markdown)
│       ├── イタリア野菜/           #   77品目の解説
│       └── 農業地域/              #   海外農業地域の伝統作物・料理
├── src/
│   ├── agents/                    # AIリサーチエージェント
│   ├── schemas/                   # Pydantic データスキーマ
│   └── validators/                # データバリデーション
├── web/                           # 静的Webサイト（野菜図鑑）
├── scripts/                       # ユーティリティスクリプト
│   ├── gen_cultivation.py         #   栽培ガイド生成 (Gemini)
│   ├── gen_cuisine.py             #   料理ガイド生成 (Gemini)
│   ├── gen_icons.py               #   野菜アイコン生成 (Gemini)
│   ├── research_regions.py        #   海外農業地域リサーチ (Gemini/Claude)
│   └── extract_varieties*.py      #   品種データ抽出
└── docs/                          # ドキュメント・計画書
```

## 気候データ基盤

### 3つの用途

| 用途 | データソース | 解像度 | 対象 |
|------|------------|--------|------|
| **農地気候** | Open-Meteo Archive (ERA5) / AgERA5 (GEE) | 0.25° / 0.1° | 農業地域プリセット 46産地 |
| **天気予報** | Open-Meteo Forecast API | — | 生産者が自分の圃場座標で取得 |
| **世界時計** | AWS S3 ERA5 (minmax/accumu) | 0.25° global | 旅行・都市間比較 |

### 農地気候プリセット

座標は市街地を避け、実際の農地（有名農産物の生産地）に置いている。大都市はヒートアイランドの影響で農地と気候が異なるため使えない。

| 地域 | 産地数 | 例 |
|------|--------|-----|
| 日本 | 34 | 十勝平野、庄内平野、魚沼、深谷、牧之原、阿蘇高原 ... |
| イタリア | 4 | アグロ・ノチェリーノ (トマトDOP)、フォッジャ、ラグーザ、マレンマ |
| フランス | 3 | ボース平野、プロヴァンス、ロワール渓谷 |
| アメリカ | 2 | セントラルバレー (CA)、アイオワ コーンベルト |
| 東南アジア | 2 | チェンマイ、メコンデルタ |
| オーストラリア | 1 | マレー・ダーリング |

### 気候統計

10年〜30年分の daily データから算出（30年 = WMO Climate Normal）:

- 月別平均気温・降水量・日射量
- 積算温度 (GDD)、初霜・終霜日、無霜期間
- 特異現象: 猛暑日 (≥35°C)、冬日 (<0°C)、大雨日 (≥50mm)、最長無降水日

## 知識基盤のデータ

### 対象領域

| 領域 | 内容 | 状況 |
|------|------|------|
| 伝統野菜（イタリア） | 品種・栽培法・歴史 | 77品目構築済み |
| 伝統野菜（日本） | 品種・栽培法・歴史 | 計画中 |
| 伝統料理 | レシピ・食文化 | 構築中 |
| 海外農業地域 | 伝統作物・伝統料理・気候 | 構築中 (Gemini Deep Research + API) |
| 自然農法 | 栽培技術・土づくり・Jones 5原則 | 構築中 |
| 土壌生物学 | 微生物・菌根菌・土壌生態系 | 計画中 |
| 植生指数 | Sentinel-2 (NDVI, NDRE, NDMI, BSI, LAI) | 計画中 |

### データスキーマ（例）

野菜エントリー:

```json
{
  "id": "IT-VEG-TOM-001",
  "names": {
    "local": "Pomodoro San Marzano",
    "japanese": "サンマルツァーノトマト",
    "english": "San Marzano Tomato",
    "scientific": "Solanum lycopersicum 'San Marzano'"
  },
  "cultivation": { "sowing_period": "...", "natural_farming_tips": "..." },
  "related_recipes": ["IT-RCP-PIZ-001"],
  "metadata": { "confidence_score": 0.92 }
}
```

## 技術スタック

| 用途 | 技術 |
|------|------|
| アプリ（記録・アルバム・販売Web・動画） | Flutter |
| バックエンド | FastAPI (grow-server, climate-server) |
| 気候データ | ERA5 (Open-Meteo / AWS S3), AgERA5 (GEE), NetCDF |
| 植生指数 | Sentinel-2 via Earth Search STAC |
| 農地マッピング | 農水省筆ポリゴン → 0.1°グリッド |
| リサーチエンジン | Claude Agent SDK + WebSearch |
| バッチ処理 | Gemini API |
| データ形式 | JSON / CSV / Markdown / NetCDF |
| データ検証 | Pydantic v2 |

## ライセンス

このプロジェクトはダブルライセンスで提供されます。

### コード部分

| ライセンス | 用途 |
|-----------|------|
| **AGPL-3.0** | オープンソース利用（デフォルト） |
| **商用ライセンス** | App Store配布など、AGPLが適用できない場合 |

### データ部分 (`data/` ディレクトリ)

**CC BY-SA 4.0** (Creative Commons Attribution-ShareAlike 4.0 International)

## AIseed との関係

このプロジェクトは [AIseed](https://github.com/aiseed) プラットフォームの一部です。

- **Grow**: 栽培記録・アルバム・販売Web・動画作成アプリ（このリポジトリの `grow/`）
- **Learn**: 伝統野菜・料理に関する学習コンテンツを自動生成
- **BYOA**: ユーザー自身の Claude Pro / Gemini でカスタム調査可能

## コントリビューション

伝統野菜・伝統料理・自然農法の情報追加を歓迎します。

1. Fork してローカルにクローン
2. `data/` 配下に情報を追加
3. Pull Request を送信

### ID 命名規則

- 野菜: `{国コード}-VEG-{カテゴリ}-{番号}` (例: `JP-VEG-KYO-001`)
- 料理: `{国コード}-RCP-{カテゴリ}-{番号}` (例: `JP-RCP-KYT-001`)

## 作者

Yasuhiro Niji ([@awoni](https://github.com/awoni))
