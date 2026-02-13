# Grow GPU Server

ローカルGPUを活用した栽培支援APIサーバー。
Claude Agent SDK によるAIチャット、OCR、画像分析、天気予報、サイト生成などを提供。

## ディレクトリ配置

```
/home/growapi/
├── .claude/              ← claude login の認証情報（自動生成）
├── .local/bin/claude     ← Claude Code CLI バイナリ（自動生成）
├── app/aiseed-tool/      ← リポジトリ（git clone）
│   ├── gpu-server/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   ├── routers/      ← APIエンドポイント
│   │   ├── services/     ← ビジネスロジック
│   │   ├── models/       ← DBモデル
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
cd aiseed-tool/gpu-server
conda env update -f environment.yml -p ./.venv --prune
conda activate ./.venv

# 6b. OSのpython3を使用する場合
cd aiseed-tool/gpu-server
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

### 天気 (`/weather`)

Ecowitt 気象ステーションのデータ受信・閲覧。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/data/report` | Ecowitt データ受信 |
| GET | `/weather/latest` | 最新の気象データ |
| GET | `/weather/history` | 気象データ履歴 |
| GET | `/weather/summary` | 気象サマリー |

### AMeDAS (`/amedas`)

気象庁AMeDASのデータ取得・閲覧。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/amedas/stations/sync` | 観測地点マスター同期 |
| GET | `/amedas/stations` | 観測地点一覧 |
| POST | `/amedas/fetch` | 観測データ取得 |
| POST | `/amedas/fetch/range` | 期間指定データ取得 |
| GET | `/amedas/data/latest` | 最新の観測データ |
| GET | `/amedas/data/history` | 観測データ履歴 |
| GET | `/amedas/data/summary` | 日別サマリー |

### 天気予報 (`/forecast`)

ECMWF予報データ（気温・降水・土壌）。

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/forecast/ecmwf` | ECMWF気象予報 |
| GET | `/forecast/soil` | 土壌予報（温度・水分） |
| GET | `/forecast/daily` | 日別予報サマリー |

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

## 環境変数（.env）

```
GROW_GPU_HOST=0.0.0.0
GROW_GPU_PORT=8000
GROW_GPU_SECRET_KEY=your-secret-key-here
GROW_GPU_APPLE_CLIENT_ID=dev.aiseed.grow
GROW_GPU_GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GROW_GPU_DATABASE_URL=sqlite+aiosqlite:///./grow_gpu.db
GROW_GPU_FLORENCE_MODEL=microsoft/Florence-2-base
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

### SECRET_KEY の自動生成

初回起動時に `SECRET_KEY` がデフォルト値のままであれば、安全なランダムキーを自動生成して `.env` に書き込む。
手動で設定する必要はない。既に設定済みの場合はそのまま使用される。

### Apple / Google ソーシャルログイン

個人利用では設定不要。未設定でもメール/パスワード認証（`/auth/register` + `/auth/login`）は動作する。
一般公開時に Apple Developer Console / Google Cloud Console で取得して設定する。

## systemd サービス化

手動起動（`python main.py`）ではなく、systemd で管理する。
自動起動・クラッシュ時再起動・ジャーナルログが使える。

```bash
# 1. サービスファイルをコピー
sudo cp grow-gpu.service /etc/systemd/system/

# 2. systemd に登録
sudo systemctl daemon-reload
sudo systemctl enable grow-gpu

# 3. 起動
sudo systemctl start grow-gpu

# 4. 状態確認
sudo systemctl status grow-gpu

# ログ確認
journalctl -u grow-gpu -f

# 再起動（コード更新後）
sudo systemctl restart grow-gpu
```

Miniforge3 を使う場合は `ExecStart` のパスを conda 環境のものに変更する:
```
ExecStart=/home/growapi/app/aiseed-tool/gpu-server/.venv/bin/python main.py
```

## 技術スタック

- **フレームワーク**: FastAPI + Uvicorn
- **AI**: Claude Agent SDK（Max定額プラン、APIキー不要）
- **OCR**: PaddleOCR + PaddlePaddle GPU
- **画像分析**: Florence-2（microsoft/Florence-2-base）
- **DB**: SQLite + SQLAlchemy（async）
- **メール**: Postfix + DKIM（aiseed.dev）
- **Python環境**: Miniforge3 / conda-forge 推奨
