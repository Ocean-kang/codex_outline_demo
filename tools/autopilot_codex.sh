#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash tools/autopilot_codex.sh \
    --spec SPEC.md \
    --remote gpu4090d \
    --remote-repo-dir /home/master/code/codex_outline_demo \
    --local-log-dir /mnt/g/Github/codex_outline_demo/logs \
    --max-iters 5 \
    --min-score 0.90
USAGE
}

SPEC=""
REMOTE=""
REMOTE_REPO_DIR=""
LOCAL_LOG_DIR=""
MAX_ITERS=5
MIN_SCORE=0.90

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec) SPEC="$2"; shift 2;;
    --remote) REMOTE="$2"; shift 2;;
    --remote-repo-dir) REMOTE_REPO_DIR="$2"; shift 2;;
    --local-log-dir) LOCAL_LOG_DIR="$2"; shift 2;;
    --max-iters) MAX_ITERS="$2"; shift 2;;
    --min-score) MIN_SCORE="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$SPEC" || -z "$REMOTE" || -z "$REMOTE_REPO_DIR" || -z "$LOCAL_LOG_DIR" ]]; then
  echo "Missing required args." >&2
  usage
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 基本保护：确保在 git repo 里
git rev-parse --is-inside-work-tree >/dev/null

mkdir -p .autolog
echo ".autolog/" >> .gitignore 2>/dev/null || true

# 远端输出不要放 repo 里（避免 git clean -fd 清掉）
REMOTE_OUT_ROOT="/home/master/outputs/$(basename "$ROOT")/runs"

for i in $(seq 1 "$MAX_ITERS"); do
  echo "================ ITER $i/$MAX_ITERS ================"

  # ---- 1) Codex 生成/修改代码（允许 workspace 写；禁用审批避免卡住；不建议 yolo） :contentReference[oaicite:3]{index=3}
  SPEC_TEXT="$(cat "$SPEC")"
  CODEX_OUT=".autolog/codex_iter_${i}.txt"

  codex exec \
    --sandbox workspace-write \
    "$SPEC_TEXT

额外约束：
- 你只能改工作区代码（.py、tests 等），不要做 git push/ssh/scp（这些由外层脚本做）。
- 修改后请确保：pytest -q 通过。
- 如果存在 .autolog/last_run/ 里的 run.log 或 metrics.json，请阅读并据此改进。
" | tee "$CODEX_OUT"

  # ---- 2) 本地测试（你也可以在这里加格式化/静态检查）
  ./.venv/bin/python -m pytest -q

  # ---- 3) 自动提交并 push
  git add -A
  if git diff --cached --quiet; then
    echo "[warn] no changes to commit (Codex may have made no edits)."
  else
    git commit -m "codex autopilot iter $i"
    git push
  fi

  COMMIT="$(git rev-parse --short HEAD)"
  RUN_ID="$(date +%Y%m%d_%H%M%S)_${COMMIT}_iter${i}"
  REMOTE_OUT_DIR="${REMOTE_OUT_ROOT}/${RUN_ID}"
  LOCAL_RUN_DIR="${LOCAL_LOG_DIR}/${RUN_ID}"

  echo "[remote] sync + run; REMOTE_OUT_DIR=$REMOTE_OUT_DIR"
  ssh "$REMOTE" "set -e;
    if [ ! -d \"$REMOTE_REPO_DIR/.git\" ]; then
      echo 'ERROR: remote repo missing at $REMOTE_REPO_DIR (clone it once first)'; exit 3;
    fi
    cd \"$REMOTE_REPO_DIR\";
    git fetch origin;
    git reset --hard origin/main;
    git clean -fd;
    mkdir -p \"$REMOTE_OUT_DIR\";
    bash tools/run_remote.sh \"$REMOTE_OUT_DIR\" 123 2>&1 | tee \"$REMOTE_OUT_DIR/run.log\";
  "

  # ---- 4) 拉回远端产物到你指定的本地 logs 目录
  mkdir -p "$LOCAL_RUN_DIR"
  scp -r "$REMOTE:$REMOTE_OUT_DIR" "$LOCAL_RUN_DIR/"

  # 同时复制一份到 repo 内，方便下一轮 Codex 读取（sandbox workspace-write 默认只看工作区）:contentReference[oaicite:4]{index=4}
  rm -rf .autolog/last_run
  mkdir -p .autolog/last_run
  cp -a "$LOCAL_RUN_DIR/$(basename "$REMOTE_OUT_DIR")"/* .autolog/last_run/ || true

  # ---- 5) 评估是否达标
  METRICS=".autolog/last_run/metrics.json"
  if [[ ! -f "$METRICS" ]]; then
    echo "[fail] metrics.json not found in .autolog/last_run/ (check run.log)."
  else
    if python3 tools/eval_metrics.py "$METRICS" "$MIN_SCORE"; then
      echo "[done] 达标，停止。logs 在：$LOCAL_RUN_DIR/$(basename "$REMOTE_OUT_DIR")"
      exit 0
    fi
  fi

  # ---- 6) 不达标：继续同一会话（resume --last）:contentReference[oaicite:5]{index=5}
  codex exec resume --last \
    --sandbox workspace-write \
    --ask-for-approval never \
    "上一轮不达标。请阅读 .autolog/last_run/metrics.json 和 .autolog/last_run/run.log（如存在），分析原因并直接修改代码和测试，让指标满足：ok=true 且 score >= $MIN_SCORE。修改后请确保 pytest -q 仍然通过。"
done

echo "[fail] 超过最大迭代次数仍未达标。最后一轮 logs 在：$LOCAL_RUN_DIR/$(basename "$REMOTE_OUT_DIR")"
exit 1