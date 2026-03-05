from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run_solution(out_dir: Path, seed: int) -> dict:
    out_dir.mkdir(parents=True, exist_ok=True)
    subprocess.check_call(
        [
            sys.executable,
            "-m",
            "src.solution",
            "--out",
            str(out_dir),
            "--seed",
            str(seed),
        ]
    )
    return json.loads((out_dir / "metrics.json").read_text(encoding="utf-8"))


def test_solution_writes_expected_metrics(tmp_path: Path) -> None:
    metrics = run_solution(tmp_path / "run", seed=123)

    assert metrics["ok"] is True
    assert isinstance(metrics["score"], float)
    assert 0.0 <= metrics["score"] <= 1.0
    assert metrics["score"] >= 0.90
    assert isinstance(metrics["details"], str)
    assert metrics["details"]


def test_solution_is_deterministic_for_same_seed(tmp_path: Path) -> None:
    m1 = run_solution(tmp_path / "a", seed=123)
    m2 = run_solution(tmp_path / "b", seed=123)

    assert m1["score"] == m2["score"]
    assert m1["ok"] == m2["ok"]
