from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

def run_pipeline(out_dir: Path) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable, "-m", "src.pipeline",
        "--out", str(out_dir),
        "--seed", "123",
        "--n-samples", "300",
        "--epochs", "60",
        "--lr", "0.15",
    ]
    subprocess.check_call(cmd)
    return json.loads((out_dir / "metrics.json").read_text(encoding="utf-8"))

def test_determinism(tmp_path: Path):
    a = run_pipeline(tmp_path / "a")
    b = run_pipeline(tmp_path / "b")
    assert a == b
