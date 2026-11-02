# Maintenance instructions for AI agents

This repository is maintained partly by automated agents (see
pablosancheznunez/research-tools-ops). Follow these rules.

## Test commands

- `pip install -e .[test] && python -m pytest -q` must pass.
- The R package in `r/` is checked in CI (`Rscript -e 'devtools::test("r")'`).

## What you may change on your own

- Compatibility fixes for new versions of NumPy, Pillow or the R packages, as long as every test still passes unchanged.
- The HTML report layout, documentation and the site.

## What you must never change

- `ALGORITHMS.md`, `src/reproimage/hashing.py`, `r/R/hashing.R`, the thresholds in `analysis.py` and `r/R/analysis.R`, `reference/` and `r/tests/testthat/reference/`. These define what the tool detects. Propose changes in an issue instead.
- Workflows, `.maintenance.json`, `CODEOWNERS` and this file.
- Never weaken or delete a test to make it pass.

## Principles

- Results describe visual relations, never misconduct. Keep the expert-review caveat in every report.
- Python depends only on NumPy and Pillow; R only on png, jpeg, tiff, digest and jsonlite.
