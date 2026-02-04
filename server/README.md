# Grow Server (Cloudflare Workers)

Grow アプリのプレミアム機能用サーバーです。
各ユーザーが自分の Cloudflare アカウントにデプロイして使用します。

## 機能

- **植物同定** (`POST /identify`) - Claude Vision による作物・雑草の同定
- **写真ストレージ** (`/photos`) - Cloudflare R2 による写真の保存・取得
- **データ同期** (`/sync`) - スマホ・デスクトップ間のデータ同期（D1）

## セットアップ

### 1. 前提条件

- [Cloudflare アカウント](https://dash.cloudflare.com/sign-up) (無料プランで可)
- [Node.js](https://nodejs.org/) v18+
- [Anthropic API キー](https://console.anthropic.com/)

### 2. インストール

```bash
cd server
npm install
```

### 3. R2 バケットの作成

```bash
npx wrangler r2 bucket create grow-photos
```

### 4. D1 データベースの作成

```bash
npx wrangler d1 create grow-db
```

表示された `database_id` を `wrangler.toml` の `database_id` に設定してから、スキーマを適用:

```bash
npx wrangler d1 execute grow-db --file=schema.sql
```

### 5. シークレットの設定

```bash
# 認証トークン（アプリに入力するトークンと同じもの）
npx wrangler secret put AUTH_TOKEN

# Anthropic API キー（Claude Vision 用）
npx wrangler secret put ANTHROPIC_KEY
```

### 6. デプロイ

```bash
npm run deploy
```

デプロイ後に表示される URL（例: `https://grow-server.<your-subdomain>.workers.dev`）を
Grow アプリの設定画面「サーバーURL」に入力してください。

## ローカル開発

```bash
npm run dev
```

`http://localhost:8787` でサーバーが起動します。

ローカル開発時にシークレットを設定するには `.dev.vars` ファイルを作成:

```
AUTH_TOKEN=your-dev-token
ANTHROPIC_KEY=sk-ant-...
```

## API

### `POST /identify`

写真から植物を同定します。

```
Content-Type: multipart/form-data
Authorization: Bearer <token>

Body: image (file)
```

レスポンス:
```json
{
  "results": [
    {
      "name": "トマト",
      "confidence": 0.95,
      "description": "本葉4枚程度の苗。健康状態は良好。"
    }
  ]
}
```

### `POST /photos`

写真をアップロードします。

```
Content-Type: multipart/form-data
Authorization: Bearer <token>

Body: image (file)
```

レスポンス:
```json
{
  "key": "2024/06/15/1718441234567-a1b2c3.jpg",
  "size": 1234567
}
```

### `GET /photos/:key`

写真を取得します。

### `DELETE /photos/:key`

写真を削除します。

### `GET /photos?prefix=2024/06/&cursor=...`

写真の一覧を取得します。

### `POST /sync/pull`

サーバーの更新データを取得します。

```json
{ "since": "2024-06-15T00:00:00.000Z" }
```

レスポンス: 各テーブルの更新レコード + 削除情報 + タイムスタンプ

### `POST /sync/push`

ローカルの更新データを送信します。

```json
{
  "locations": [...],
  "plots": [...],
  "crops": [...],
  "records": [...],
  "record_photos": [...],
  "observations": [...],
  "observation_entries": [...],
  "deleted": [{ "id": "...", "table_name": "..." }]
}
```

### `GET /health`

ヘルスチェック。

## コスト目安

| サービス | 無料枠 | 超過時 |
|---------|--------|--------|
| Workers | 10万リクエスト/日 | $0.30/100万リクエスト |
| R2 ストレージ | 10GB | $0.015/GB/月 |
| R2 読み取り | 1000万/月 | $0.36/100万 |
| R2 書き込み | 100万/月 | $4.50/100万 |
| D1 ストレージ | 5GB | $0.75/GB/月 |
| D1 読み取り | 500万行/日 | $0.001/1000行 |
| D1 書き込み | 10万行/日 | $1.00/100万行 |
| Claude API | なし | ~$0.003/画像 (Sonnet) |

個人利用では Cloudflare の無料枠内に収まることが多いです。
主なコストは Claude API の画像同定です（1回あたり約0.5円）。
