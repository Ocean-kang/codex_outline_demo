# codex_outline_demo (verified minimal demo)

这个 demo 用来验证一条“低干预自动化”的开发链路：

- 本地（WSL）：
  - 自动创建 `.venv` 并安装 pytest
  - 运行 `python tools/validate_outline.py`
  - 运行 `pytest -q`
- 远端（GPU 服务器，通过 SSH 别名 `gpu4090d`）：
  - 在 `--repo-dir` 指定目录中强制同步到 `origin/main`
  - 执行一个确定性的 pipeline：`python3 -m src.pipeline ...`
  - 输出 `metrics.json` 并打印摘要行 `accuracy=... loss=... out=...`

> 该 demo 不依赖第三方 Python 包（除 pytest 用于测试），pipeline 完全使用标准库，便于在“远端无法出海装包”的情况下跑通。

---

## 1) 本地准备（WSL / Ubuntu 24.04）

```bash
sudo apt update

sudo apt install -y python3-venv
```

（可选）确认你能出海（通过 Windows portproxy 18080→10808）：

```bash
WIN_HOST=$(ip route | awk '/default/ {print $3; exit}')
export HTTP_PROXY="http://$WIN_HOST:18080"
export HTTPS_PROXY="http://$WIN_HOST:18080"
curl -I https://github.com --max-time 10
```

---

### 1.1) （补充）本地安装 Codex CLI（如果你要体验 `codex` / `codex exec`）

```bash
# 推荐使用 nvm 安装 Node，避免 sudo npm -g 的权限问题
sudo apt install -y curl ca-certificates
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc

nvm install 18
nvm use 18

WIN_HOST=$(ip route | awk '/default/ {print $3; exit}')
PROXY="http://$WIN_HOST:18080"
npm config set proxy "$PROXY"
npm config set https-proxy "$PROXY"

npm i -g @openai/codex
codex --version
codex login
```

> 注意：本 demo 的 `tools/full_auto.sh` 不强制调用 Codex CLI；安装 Codex 的目的是让你在此 demo 基础上练习 `codex exec` 自动修复/实现工作流。

## 2) 运行（本地 + 远端）

确保你已配置：
- `ssh gpu4090d` 能连通远端
- 本仓库已 push 到 GitHub，并且远端能访问 GitHub（至少能 clone）

运行：

```bash
bash tools/full_auto.sh --remote gpu4090d --repo-dir /home/zyy/code/codex_outline_demo
```

---

## 3) 单独运行本地 checks

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip pytest
python tools/validate_outline.py
pytest -q
```

---

## 4) 单独运行 pipeline

```bash
python -m src.pipeline --out /tmp/pipeline_check --seed 123 --n-samples 300 --epochs 60 --lr 0.15
cat /tmp/pipeline_check/metrics.json
```
