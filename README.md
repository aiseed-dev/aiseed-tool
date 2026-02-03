# aiseed-tool

**AI x 自然栽培** -- 伝統野菜の知識基盤と栽培記録ツール

## 概要

自然栽培の記録をつけるための Flutter アプリと、それを支える知識基盤のプロジェクトです。

知識基盤には、イタリア・日本の伝統野菜と伝統料理のデータに加え、自然農法や土壌生物学の知識を収録します。全文検索や AI による検索で、栽培に必要な情報にすぐアクセスできることを目指します。

除草するためではなく、共生するためのツールです。

## 特徴

- **栽培記録**: 日々の観察・作業をシンプルに記録する Flutter アプリ
- **知識基盤**: 伝統野菜・伝統料理・自然農法・土壌生物学の構造化データ
- **情報検索**: 全文検索 + AI 検索で知識基盤から必要な情報を引き出す
- **マルチAIリサーチ**: Claude（深堀り調査）+ Gemini（バッチ処理）でデータを構築
- **多言語対応**: イタリア語・日本語・英語のソースを直接調査

## プロジェクト構成

```
aiseed-tool/
├── grow/                          # Flutter 栽培記録アプリ
├── data/
│   ├── vegetables/                # 伝統野菜データ (JSON)
│   ├── recipes/                   # 伝統料理データ (JSON)
│   ├── master_lists/              # マスターデータ (CSV)
│   └── deep_research/             # 深堀り調査結果 (Markdown)
├── src/
│   ├── agents/                    # AIリサーチエージェント
│   ├── schemas/                   # Pydantic データスキーマ
│   └── validators/                # データバリデーション
├── web/                           # 静的Webサイト（野菜図鑑）
├── scripts/                       # ユーティリティスクリプト
└── docs/                          # ドキュメント・計画書
```

## 知識基盤のデータ

### 対象領域

| 領域 | 内容 | 状況 |
|------|------|------|
| 伝統野菜（イタリア） | 品種・栽培法・歴史 | 構築中 |
| 伝統野菜（日本） | 品種・栽培法・歴史 | 計画中 |
| 伝統料理 | レシピ・食文化 | 構築中 |
| 自然農法 | 栽培技術・土づくり | 計画中 |
| 土壌生物学 | 微生物・菌根菌・土壌生態系 | 計画中 |

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
| 栽培記録アプリ | Flutter |
| リサーチエンジン | Claude Agent SDK + WebSearch |
| バッチ処理 | Gemini API |
| データ形式 | JSON / CSV / Markdown |
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

- **Grow**: 栽培記録アプリ（このリポジトリの `grow/`）
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
