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

Apple / Google ソーシャルログイン対応。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/auth/login/apple` | Apple Sign In |
| POST | `/auth/login/google` | Google Sign In |

### OCR (`/ocr`)

PaddleOCR による画像内テキスト認識（日本語・英語・イタリア語）。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/ocr/recognize` | 画像からテキスト抽出 |

### 画像分析 (`/vision`)

Florence-2 による植物識別・画像キャプション。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/vision/identify` | 植物識別 |
| POST | `/vision/caption` | 画像キャプション生成 |

### 天気 (`/weather`, `/amedas`, `/forecast`)

気象庁データを活用。

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/weather/current` | 現在の天気 |
| GET | `/amedas/latest` | AMeDAS観測データ |
| GET | `/forecast/weekly` | 週間天気予報 |

### スキルファイル (`/skillfile`)

ユーザーの栽培プロフィールからAI用スキルファイルを生成。ログイン不要。

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/skillfile/generate` | スキルファイル生成 |

### 栽培記録 (`/grow`)

栽培記録のCRUD操作。

| メソッド | パス | 説明 |
|---|---|---|
| GET | `/grow/records` | 記録一覧 |
| POST | `/grow/records` | 記録作成 |

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

## 技術スタック

- **フレームワーク**: FastAPI + Uvicorn
- **AI**: Claude Agent SDK（Max定額プラン、APIキー不要）
- **OCR**: PaddleOCR + PaddlePaddle GPU
- **画像分析**: Florence-2（microsoft/Florence-2-base）
- **DB**: SQLite + SQLAlchemy（async）
- **メール**: Postfix + DKIM（aiseed.dev）
- **Python環境**: Miniforge3 / conda-forge 推奨
