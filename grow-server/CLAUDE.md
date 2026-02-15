# Grow Server — セットアップ手順

栽培支援APIサーバー。AIチャット、OCR、画像分析、サイト生成、消費者プラットフォームを提供する。

## 前提条件

- Linux サーバー（Ubuntu 推奨）
- Python 3.12
- GPU（CUDA 12.x）推奨、CPU のみでも基本機能は動作

## セットアップ

### 1. ユーザー作成

```bash
sudo useradd -m -s /bin/bash growapi
sudo su -s /bin/bash - growapi
```

### 2. Claude Code CLI（AIチャット機能に必要）

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude   # Max プランでログイン
```

### 3. リポジトリ取得

```bash
mkdir app && cd app
git clone <リポジトリURL>
cd aiseed-tool/grow-server
```

### 4. Python 環境

#### Miniforge3 推奨（GPU 利用時）

```bash
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
conda config --set auto_activate_base false
conda env update -f environment.yml -p ./.venv --prune
conda activate ./.venv
```

#### venv（GPU 不要時）

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 5. PaddlePaddle GPU（OCR に必要、GPU ありの場合のみ）

`nvidia-smi` で CUDA バージョンを確認して対応するものをインストール:

```bash
# CUDA 12.6 の場合
pip install paddlepaddle-gpu==3.3.0 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/

# CUDA のバージョンに合わせて cu118 / cu126 / cu129 / cu130 を選択
```

### 6. 環境変数

```bash
cp .env.example .env
```

最低限 `GROW_GPU_SECRET_KEY` を設定する。
初回起動時にデフォルト値のままなら安全なキーが自動生成される。

その他の設定:
- `GROW_GPU_ALLOW_LOCAL_REGISTER`: `false` で公開サーバーのローカル登録を無効化
- ソーシャルログイン: 個人利用なら設定不要

### 7. 起動

```bash
python main.py
```

`http://localhost:8000/docs` で Swagger UI を確認。

### 8. systemd サービス化（本番運用）

```bash
sudo cp grow-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable grow-server
sudo systemctl start grow-server
```

## 主要機能

| 機能 | エンドポイント | GPU |
|---|---|---|
| AIチャット | POST /ai/chat | 不要（Claude Max） |
| 認証 | /auth/* | 不要 |
| OCR | /ocr/* | 推奨 |
| 画像分析 | /vision/* | 必要 |
| スキルファイル | POST /skillfile/generate | 不要 |
| 栽培記録同期 | /grow/sync/* | 不要 |
| サイト生成 | /sites/* | 不要 |
| 筆ポリゴン | /fude/* | 不要 |
| QRコード | GET /qr/generate | 不要 |
| 消費者プラットフォーム | /consumer/* | 不要 |
| 管理者 | /admin/* | 不要 |

## ロールと機能制御

- **admin**: 全機能 + 管理者API
- **super_user**: 管理以外の全機能
- **user**: `users.yaml` で許可された機能のみ
- **pending**: プロフィールのみ（承認待ち）
