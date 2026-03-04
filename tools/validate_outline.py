#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

REQUIRED_HEADINGS = [
    "# Outline",
    "## Goal",
    "## Steps",
]

def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    outline = root / "outline.md"
    if not outline.exists():
        print(f"[validate] missing: {outline}", file=sys.stderr)
        return 2
    text = outline.read_text(encoding="utf-8", errors="replace")
    missing = [h for h in REQUIRED_HEADINGS if h not in text]
    if missing:
        print("[validate] missing headings:", ", ".join(missing), file=sys.stderr)
        return 3
    print("outline validation: OK")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
