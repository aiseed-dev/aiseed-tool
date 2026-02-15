# 自然栽培コワーク（Grow）

農家が一人でAIとチームを組むための栽培支援プラットフォーム。

## 設計方針

- **ローカルファースト** — 基本処理はすべて農家のPC上で完結する
- Windows環境では WSL 上で grow-server を動かす
- cloudflare-server は PCを持たない農家向けと、ローカルサーバーのWeb公開・バックアップ用

## プロジェクト構成

```
grow/                 ← スマホアプリ（Flutter / iOS・Android）
grow_cowork/          ← デスクトップアプリ（Flutter + Python scripts）
grow-server/          ← ローカルAPIサーバー（FastAPI / GPU対応）
server/               ← 中央サーバー（気象・衛星データ等）
cloudflare-server/    ← エッジサーバー（Cloudflare Workers）
web/                  ← Webサイト
data/                 ← データ
```

## セットアップ

農家の利用シーンに応じて以下を選択する。

### デスクトップ利用（grow_cowork）

個人PCで栽培記録・写真管理・AI植物同定を使う場合。
GPU不要。Python + Anthropic APIキーがあれば動く。

→ `grow_cowork/CLAUDE.md` の手順に従う

### サーバー運用（grow-server）

OCR・画像分析・天気予報・サイト生成など全機能を使う場合。
GPU推奨。Linux サーバー向け（WindowsはWSL利用）。

→ `grow-server/CLAUDE.md` の手順に従う

## 開発ルール

- シンプルに保つ。過剰な抽象化はしない
- 日本語コメント推奨
- DB は SQLite（async）
- 認証は JWT
