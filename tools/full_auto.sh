#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash tools/full_auto.sh --remote <ssh-host-alias> --repo-dir <remote-path>

Example:
  bash tools/full_auto.sh --remote gpu4090d --repo-dir /home/zyy/code/codex_outline_demo
USAGE
}

REMOTE=""
REMOTE_REPO_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) REMOTE="$2"; shift 2;;
    --repo-dir) REMOTE_REPO_DIR="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$REMOTE" || -z "$REMOTE_REPO_DIR" ]]; then
  echo "Missing required args." >&2
  usage
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# --- Local venv bootstrap (Ubuntu 24.04: avoid PEP 668 system pip) ---
VENV="$ROOT/.venv"
PY="$VENV/bin/python"

if [[ ! -x "$PY" ]]; then
  echo "[local] creating venv at $VENV"
  python3 -m venv "$VENV"
  "$PY" -m pip install -U pip pytest
fi

echo "[local] validate outline"
"$PY" tools/validate_outline.py

echo "[local] run tests"
"$PY" -m pytest -q

# --- Remote sync + run ---
# Remote should be a runner (clean, reproducible): force sync to origin/main.
REMOTE_URL="$(git config --get remote.origin.url || true)"
if [[ -z "$REMOTE_URL" ]]; then
  echo "ERROR: current repo has no remote.origin.url" >&2
  exit 3
fi

echo "[remote] ensuring repo exists at $REMOTE_REPO_DIR"
ssh "$REMOTE" "mkdir -p "$(dirname "$REMOTE_REPO_DIR")";   if [ ! -d "$REMOTE_REPO_DIR/.git" ]; then     git clone "$REMOTE_URL" "$REMOTE_REPO_DIR";   fi"

echo "[remote] force sync to origin/main (no divergent pull prompts)"
ssh "$REMOTE" "set -e; cd "$REMOTE_REPO_DIR";   git fetch origin;   git reset --hard origin/main;   git clean -fd"

echo "[remote] run deterministic pipeline smoke"
# ssh "$REMOTE" "set -e; cd "$REMOTE_REPO_DIR";   python3 -m src.pipeline --out /tmp/pipeline_check --seed 123 --n-samples 300 --epochs 60 --lr 0.15"
ssh "$REMOTE" "set -e; cd \"$REMOTE_REPO_DIR\"; python3 -m src.pipeline --out \"$REMOTE_REPO_DIR/pipeline_check\" --seed 123 --n-samples 300 --epochs 60 --lr 0.15"
echo "[done] local+remote checks complete."
