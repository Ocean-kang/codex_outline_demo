#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import time
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True)
class Metrics:
    accuracy: float
    loss: float

def deterministic_metrics(seed: int, n_samples: int, epochs: int, lr: float) -> Metrics:
    """Deterministic, purely functional toy metric generator."""
    # Combine inputs into a stable seed (avoid platform randomness).
    payload = f"{seed}|{n_samples}|{epochs}|{lr}".encode("utf-8")
    h = hashlib.sha256(payload).hexdigest()
    # Use part of hash to seed a local PRNG.
    local_seed = int(h[:16], 16) ^ seed
    rng = random.Random(local_seed)

    # Produce stable pseudo-metrics
    # accuracy in [0.5, 1.0), loss in (0.0, 1.0]
    acc = 0.5 + 0.5 * rng.random()
    loss = 1.0 / (1.0 + epochs * lr) + 0.05 * rng.random()

    # Round to stabilize JSON + printing (avoid float repr drift)
    return Metrics(accuracy=round(acc, 6), loss=round(loss, 6))

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True, help="output directory")
    p.add_argument("--seed", type=int, default=123)
    p.add_argument("--n-samples", type=int, default=300)
    p.add_argument("--epochs", type=int, default=60)
    p.add_argument("--lr", type=float, default=0.15)
    args = p.parse_args()

    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    m = deterministic_metrics(args.seed, args.n_samples, args.epochs, args.lr)

    metrics_path = out_dir / "metrics.json"
    metrics_path.write_text(json.dumps({"accuracy": m.accuracy, "loss": m.loss}, indent=2) + "\n", encoding="utf-8")

    # Required format summary
    print(f"accuracy={m.accuracy} loss={m.loss} out={out_dir}")

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
