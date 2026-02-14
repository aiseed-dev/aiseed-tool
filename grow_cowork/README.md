# Grow Desktop Server

デスクトップ版 Flutter アプリ用のローカルバックエンド（Python FastAPI）。
Cloudflare Workers 版と同じ API 仕様で、Flutter アプリ側のコードを共通化できます。

## 機能

- **植物同定** (`POST /identify`) - Claude Vision による作物・雑草の同定
- **写真ストレージ** (`/photos`) - ローカルファイルシステムに保存

## セットアップ

### 1. Python 環境の準備

```bash
cd desktop
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 設定

```bash
cp .env.example .env
```

`.env` を編集:

```
AUTH_TOKEN=your-secret-token
ANTHROPIC_KEY=sk-ant-...
```

### 3. 起動

```bash
python run.py
```

`http://localhost:8000` でサーバーが起動します。

Flutter アプリの設定画面で:
- サーバーURL: `http://localhost:8000`
- 認証トークン: `.env` の `AUTH_TOKEN` と同じ値

## API

Cloudflare Workers 版 (`server/README.md`) と同一仕様です。

| エンドポイント | メソッド | 説明 |
|---------------|---------|------|
| `/identify` | POST | 植物同定（Claude Vision） |
| `/photos` | POST | 写真アップロード |
| `/photos` | GET | 写真一覧 |
| `/photos/{key}` | GET | 写真取得 |
| `/photos/{key}` | DELETE | 写真削除 |
| `/health` | GET | ヘルスチェック |

## Workers 版との違い

| | Desktop (Python) | Server (Cloudflare Workers) |
|---|---|---|
| 実行場所 | ローカル PC | Cloudflare エッジ |
| 写真保存 | ローカルファイル | R2 |
| API キー | ローカル `.env` | Workers シークレット |
| 用途 | デスクトップアプリ | スマホアプリ |
