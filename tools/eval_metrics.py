#!/usr/bin/env python3
import json
import sys
from pathlib import Path

metrics_path = Path(sys.argv[1])
min_score = float(sys.argv[2])  # e.g. 0.90

m = json.loads(metrics_path.read_text(encoding="utf-8"))
ok = bool(m.get("ok", False))
score = float(m.get("score", -1))

print(f"ok={ok} score={score} file={metrics_path}")
sys.exit(0 if (ok and score >= min_score) else 1)