# Outline (demo)

## Goal
Implement a deterministic toy training pipeline and verify that the implementation matches the outline.

## Steps
1. Build a deterministic metric generator (seeded).
2. Save outputs to a user-provided directory.
3. Print a summary line in the format: `accuracy=... loss=... out=...`
4. Provide a test that two runs with the same args produce identical `metrics.json`.
