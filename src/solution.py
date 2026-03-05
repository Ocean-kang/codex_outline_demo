from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Sample:
    x: float
    y: float
    label: int


def make_dataset(seed: int, n_per_class: int = 120) -> list[Sample]:
    """Build a linearly separable synthetic dataset with deterministic noise."""
    rng = random.Random(seed)
    data: list[Sample] = []

    for _ in range(n_per_class):
        data.append(Sample(x=-1.0 + rng.gauss(0.0, 0.18), y=-1.0 + rng.gauss(0.0, 0.18), label=0))
        data.append(Sample(x=1.0 + rng.gauss(0.0, 0.18), y=1.0 + rng.gauss(0.0, 0.18), label=1))

    rng.shuffle(data)
    return data


def split_dataset(data: list[Sample], train_ratio: float = 0.8) -> tuple[list[Sample], list[Sample]]:
    cut = int(len(data) * train_ratio)
    return data[:cut], data[cut:]


def train_centroid_classifier(train_data: list[Sample]) -> dict[int, tuple[float, float]]:
    sums = {0: [0.0, 0.0, 0], 1: [0.0, 0.0, 0]}
    for s in train_data:
        sums[s.label][0] += s.x
        sums[s.label][1] += s.y
        sums[s.label][2] += 1

    centroids: dict[int, tuple[float, float]] = {}
    for label, (sx, sy, count) in sums.items():
        centroids[label] = (sx / count, sy / count)
    return centroids


def predict(centroids: dict[int, tuple[float, float]], x: float, y: float) -> int:
    c0 = centroids[0]
    c1 = centroids[1]
    d0 = math.dist((x, y), c0)
    d1 = math.dist((x, y), c1)
    return 0 if d0 <= d1 else 1


def evaluate(seed: int) -> tuple[float, str]:
    data = make_dataset(seed)
    train_data, test_data = split_dataset(data, train_ratio=0.8)
    centroids = train_centroid_classifier(train_data)

    correct = 0
    for s in test_data:
        if predict(centroids, s.x, s.y) == s.label:
            correct += 1

    score = round(correct / len(test_data), 6)
    details = (
        f"seed={seed}; train={len(train_data)}; test={len(test_data)}; "
        f"centroids={centroids}"
    )
    return score, details


def run(out_dir: Path, seed: int) -> dict[str, object]:
    out_dir.mkdir(parents=True, exist_ok=True)
    score, details = evaluate(seed)
    metrics = {
        "ok": score >= 0.90,
        "score": score,
        "details": details,
    }
    (out_dir / "metrics.json").write_text(json.dumps(metrics, ensure_ascii=False) + "\n", encoding="utf-8")
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(description="Deterministic toy train/infer pipeline")
    parser.add_argument("--out", required=True, help="Output directory")
    parser.add_argument("--seed", type=int, default=123, help="Random seed")
    args = parser.parse_args()

    out_dir = Path(args.out).expanduser().resolve()
    metrics = run(out_dir, args.seed)
    print(json.dumps(metrics, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
