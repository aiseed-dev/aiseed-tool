claude login の認証情報は ~/.claude/ に保存されるので、growapi ユーザーのホームディレクトリが重要です。

推奨ディレクトリ配置
/home/growapi/
├── .claude/              ← claude login の認証情報（自動生成）
├── .local/bin/claude     ← Claude Code CLI バイナリ（自動生成）
├── app/aiseed-tool       ← FastAPI アプリ（git clone）
│   ├── gpu-server/
│   │   ├── main.py
│   │   ├── .env
│   │   ├── .venv/
│   │   └── ...
│   └── ...
└── .bashrc               ← PATH に .local/bin を追加

セットアップ手順
# 1. growapi ユーザーとしてシェルに入る
sudo su -s /bin/bash - growapi

# 2. Claude Code CLI インストール
curl -fsSL https://claude.ai/install.sh | bash

# 3. ログイン（Pro, Max プランのアカウントで）
claude

# 4. Miniforge3のインストール（オプション）
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh
シェル起動時に base 環境を自動的にアクティブにすることを停止
conda config --set auto_activate_base false
condaのアップデート
conda update conda

# 5. ディレクトリ作成
mkdir app
cd app

# 6. リポジトリをクローン
git clone <リポジトリURL>

# 7a. OSのpython3を使用する場合
cd aiseed-tool/gpu-server
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 7b. Miniforge3を使用する場合
cd aiseed-tool/gpu-server
conda env update -f environment.yml -p ./.venv --prune
conda activate ./.venv

# 8. PaddlePaddle GPU インストール（CUDA バージョンに合わせる）
# nvidia-smi で CUDA Version を確認して選択
# cu118 / cu126 / cu129 / cu130
pip install paddlepaddle-gpu==3.3.0 -i https://www.paddlepaddle.org.cn/packages/stable/cu130/

# 9. .env 作成
cp .env.example .env
vi .env  # SECRET_KEY を設定

# 10. 動作確認
python main.py
