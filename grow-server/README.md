# Grow Server

栽培支援APIサーバー。
Claude Agent SDK によるAIチャット、OCR、画像分析、サイト生成、消費者プラットフォームなどを提供。

## ディレクトリ配置

```
/home/growapi/
├── .claude/              ← claude login の認証情報（自動生成）
├── .local/bin/claude     ← Claude Code CLI バイナリ（自動生成）
├── app/aiseed-tool/      ← リポジトリ（git clone）
│   ├── grow-server/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── routers/      ← APIエンドポイント
│   │   ├── services/     ← ビジネスロジック
│   │   ├── models/       ← DBモデル
│   │   ├── users.yaml    ← ユーザー別機能許可設定
│   │   ├── .env
│   │   └── .venv/
│   └── ...
└── .bashrc               ← PATH に .local/bin を追加
```

## セットアップ

```bash
# 1. growapi ユーザーとしてシェルに入る
sudo su -s /bin/bash - growapi

# 2. Claude Code CLI インストール
curl -fsSL https://claude.ai/install.sh | bash

# 3. ログイン（Max プランのアカウントで）
claude

# 4. Miniforge3のインストール（推奨）
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
conda config --set auto_activate_base false
conda update conda

# 5. リポジトリをクローン
mkdir app && cd app
git clone <リポジトリURL>

# 6a. Miniforge3を使用する場合（推奨）
cd aiseed-tool/grow-server
conda env update -f environment.yml -p ./.venv --prune
conda activate ./.venv

# 6b. OSのpython3を使用する場合
cd aiseed-tool/grow-server
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 7. PaddlePaddle GPU インストール（CUDA バージョンに合わせる）
# nvidia-smi で CUDA Version を確認して選択
pip install paddlepaddle-gpu==3.3.0 -i https://www.paddlepaddle.org.cn/packages/stable/cu130/

# 8. .env 作成
cp .env.example .env
vi .env  # SECRET_KEY を設定

# 9. 起動
python main.py
```

## APIエンドポイント一覧

サーバー起動後、http://localhost:8000/docs で Swagger UI を確認できる。

### ヘルスチェック

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/health` | サーバー状態・GPU情報を返す |

### AI チャット (`/ai`)

Claude Agent SDK（Max定額プラン）を使用。APIキー不要。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/ai/chat` | AIチャット（SSEストリーミング） |

### 認証 (`/auth`)

メール/パスワード + Apple / Google ソーシャルログイン対応。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/auth/register` | ユーザー登録 |
| POST | `/auth/login` | メール/パスワードログイン |
| GET | `/auth/providers` | 利用可能な認証方法を返す |
| POST | `/auth/apple` | Apple Sign In |
| POST | `/auth/google` | Google Sign In |
| GET | `/auth/me` | プロフィール取得 |
| PUT | `/auth/me` | プロフィール更新 |

### OCR (`/ocr`)

PaddleOCR による画像内テキスト認識（日本語・英語・イタリア語）。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/ocr/read` | 画像からテキスト抽出 |
| POST | `/ocr/seed-packet` | 種袋OCR（構造化データ抽出） |

### 画像分析 (`/vision`)

Florence-2 による画像キャプション・物体検出・栽培写真分析。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/vision/caption` | 画像キャプション生成 |
| POST | `/vision/detect` | 物体検出 |
| POST | `/vision/analyze` | 栽培写真の総合分析 |

### スキルファイル (`/skillfile`)

ユーザーの栽培プロフィールからAI用スキルファイルを生成。ログイン不要。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/skillfile/generate` | スキルファイル生成 |

### 栽培記録同期 (`/grow`)

スマホアプリとのデータ同期・写真管理。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/grow/sync/pull` | サーバーから差分取得 |
| POST | `/grow/sync/push` | サーバーへ差分送信 |
| POST | `/grow/photos` | 写真アップロード |
| GET | `/grow/photos/{path}` | 写真取得 |

### サイト生成 (`/sites`)

農園Webサイトの自動生成。スマホ版（バッチ）とPC版（即時）の2モード。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/sites/generate` | 即時HTML生成（PC版） |
| POST | `/sites/request` | バッチキューに追加（スマホ版） |
| GET | `/sites/status/{job_id}` | ジョブ状態確認 |
| GET | `/sites/jobs` | ユーザーのジョブ一覧 |
| POST | `/sites/deploy` | Cloudflare Pages へデプロイ |

### 筆ポリゴン (`/fude`)

農水省の農地区画データ（筆ポリゴン）のインポート・検索。GPS座標から農地を特定する。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/fude/import` | GeoJSON / ZIP ファイルをインポート |
| GET | `/fude/search` | GPS座標から農地区画を検索 |
| GET | `/fude/nearby` | 周辺の農地区画一覧 |
| GET | `/fude/stats` | インポート済みデータの統計 |

### QRコード (`/qr`)

ホームページURLからQRコード画像を生成。マルシェの値札・畑の看板・野菜の袋に貼って直販に誘導。

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/qr/generate` | QRコード生成（PNG / SVG） |

### 消費者プラットフォーム (`/consumer`)

生成された農園ホームページ上の消費者向け機能。登録・ログイン・いいね。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/consumer/register` | 消費者ユーザー登録 |
| POST | `/consumer/login` | 消費者ログイン |
| POST | `/consumer/like/{farm_username}` | いいねトグル |
| GET | `/consumer/likes/{farm_username}` | いいね数・状態取得 |

### 管理者 (`/admin`)

admin ロールのユーザーのみアクセス可能。ユーザー管理・機能設定。

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/admin/users` | 全ユーザー一覧 |
| GET | `/admin/users/stats` | ユーザー統計 |
| GET | `/admin/users/pending` | 承認待ちユーザー一覧 |
| PUT | `/admin/users/{user_id}/approve` | ユーザー承認 |
| PUT | `/admin/users/{user_id}/role` | ロール変更 |
| PUT | `/admin/users/{user_id}/deactivate` | ユーザー無効化 |
| PUT | `/admin/users/{user_id}/activate` | ユーザー有効化 |
| GET | `/admin/users/{user_id}/features` | ユーザーの利用可能機能 |
| POST | `/admin/register` | 管理者によるユーザー登録 |
| POST | `/admin/reload-config` | users.yaml 再読み込み |

## 環境変数（.env）

```
GROW_GPU_HOST=0.0.0.0
GROW_GPU_PORT=8000
GROW_GPU_SECRET_KEY=your-secret-key-here
GROW_GPU_APPLE_CLIENT_ID=dev.aiseed.grow
GROW_GPU_GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GROW_GPU_DATABASE_URL=sqlite+aiosqlite:///./grow_gpu.db
GROW_GPU_FLORENCE_MODEL=microsoft/Florence-2-base
GROW_GPU_ALLOW_LOCAL_REGISTER=true
GROW_GPU_OCR_LANGUAGES=japan,en,it
GROW_GPU_UPLOAD_DIR=./uploads
GROW_GPU_MAX_UPLOAD_SIZE=20971520
GROW_GPU_MAIL_FROM=noreply@aiseed.dev
```

| 変数 | 説明 | 必須 |
|---|---|---|
| `GROW_GPU_HOST` | バインドアドレス。`0.0.0.0` でLAN内からアクセス可能 | |
| `GROW_GPU_PORT` | ポート番号 | |
| `GROW_GPU_SECRET_KEY` | JWT署名用の秘密鍵。**必ず変更すること**（下記参照） | **必須** |
| `GROW_GPU_APPLE_CLIENT_ID` | Apple Sign In の Services ID | 公開時 |
| `GROW_GPU_GOOGLE_CLIENT_ID` | Google OAuth 2.0 Client ID | 公開時 |
| `GROW_GPU_DATABASE_URL` | SQLAlchemy接続文字列 | |
| `GROW_GPU_FLORENCE_MODEL` | Florence-2 のモデル名 | |
| `GROW_GPU_ALLOW_LOCAL_REGISTER` | `false` でローカル登録（/auth/register）を無効化。公開サーバーはソーシャルログインのみにする | |
| `GROW_GPU_OCR_LANGUAGES` | OCR対応言語（カンマ区切り） | |
| `GROW_GPU_UPLOAD_DIR` | 写真アップロード先ディレクトリ | |
| `GROW_GPU_MAX_UPLOAD_SIZE` | アップロード上限サイズ（バイト、デフォルト20MB） | |
| `GROW_GPU_MAIL_FROM` | 送信元メールアドレス | |

### SECRET_KEY の自動生成

初回起動時に `SECRET_KEY` がデフォルト値のままであれば、安全なランダムキーを自動生成して `.env` に書き込む。
手動で設定する必要はない。既に設定済みの場合はそのまま使用される。

### Apple / Google ソーシャルログイン

個人利用では設定不要。未設定でもメール/パスワード認証（`/auth/register` + `/auth/login`）は動作する。
一般公開時に Apple Developer Console / Google Cloud Console で取得して設定する。

### ユーザー別機能許可（users.yaml）

`users.yaml` で role=user のユーザーごとに利用可能な機能を制御できる。
admin / super_user はロールで全機能許可。pending はプロフィールのみ。

```yaml
users:
  taro:
    features: [ai, ocr, grow, site]
  hanako:
    features: [ai, grow]
```

利用可能な機能名: `ai`, `ocr`, `vision`, `grow`, `site`, `fude`, `qr`, `consumer`, `skillfile`

## systemd サービス化

手動起動（`python main.py`）ではなく、systemd で管理する。
自動起動・クラッシュ時再起動・ジャーナルログが使える。

```bash
# 1. サービスファイルをコピー
sudo cp grow-server.service /etc/systemd/system/

# 2. systemd に登録
sudo systemctl daemon-reload
sudo systemctl enable grow-server

# 3. 起動
sudo systemctl start grow-server

# 4. 状態確認
sudo systemctl status grow-server

# ログ確認
journalctl -u grow-server -f

# 再起動（コード更新後）
sudo systemctl restart grow-server
```

Miniforge3 を使う場合は `ExecStart` のパスを conda 環境のものに変更する:
```
ExecStart=/home/growapi/app/aiseed-tool/grow-server/.venv/bin/python main.py
```

## 技術スタック

- **フレームワーク**: FastAPI + Uvicorn
- **AI**: Claude Agent SDK（Max定額プラン、APIキー不要）
- **OCR**: PaddleOCR + PaddlePaddle GPU
- **画像分析**: Florence-2（microsoft/Florence-2-base）
- **DB**: SQLite + SQLAlchemy（async）
- **メール**: Postfix + DKIM（aiseed.dev）
- **Python環境**: Miniforge3 / conda-forge 推奨
