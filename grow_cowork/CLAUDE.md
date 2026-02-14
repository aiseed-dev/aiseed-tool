# Grow Desktop — セットアップ手順

デスクトップ版 Flutter アプリ用のローカルバックエンド。
Claude Vision による植物同定、写真管理、栽培データ同期を提供する。

## 前提条件

- Python 3.10 以上
- Anthropic API キー（Claude Vision 用）

## セットアップ

### 1. Python 環境

```bash
cd grow_cowork
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 環境変数

```bash
cp .env.example .env
```

`.env` に以下を設定する:

- `AUTH_TOKEN`: Flutter アプリとの認証トークン（任意の文字列を生成する）
- `ANTHROPIC_KEY`: Anthropic API キー（`sk-ant-` で始まる）

AUTH_TOKEN は `python3 -c "import secrets; print(secrets.token_urlsafe(32))"` で生成できる。

### 3. 起動

```bash
python run.py
```

`http://localhost:8000` で起動する。`/health` で動作確認。

### 4. Flutter アプリの設定

Flutter アプリの設定画面で以下を入力:
- サーバーURL: `http://localhost:8000`
- 認証トークン: `.env` の `AUTH_TOKEN` と同じ値

## ディレクトリ構成

```
grow_cowork/
├── grow_cowork/       ← Flutter アプリ本体（Dart）
├── scripts/           ← Python バックエンド（FastAPI）
│   ├── main.py        ← FastAPI アプリ定義
│   ├── auth.py        ← Bearer トークン認証
│   ├── identify.py    ← Claude Vision 植物同定
│   ├── photos.py      ← 写真ストレージ
│   ├── sync.py        ← SQLite データ同期
│   └── config.py      ← 環境変数読み込み
├── run.py             ← サーバー起動スクリプト
├── requirements.txt   ← Python 依存パッケージ
└── .env.example       ← 環境変数テンプレート
```
