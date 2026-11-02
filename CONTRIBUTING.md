# Contributing

Thank you for helping improve ReproImage. Bug reports with a minimal image pair, new reference cases and proposals for the next algorithm version are welcome.

## Running the tests

- Python: `pip install -e .[test] && python -m pytest -q`.
- R package: `R CMD build r && R CMD check --as-cran reproimage_*.tar.gz`.

Both implementations must give identical results on the reference images; the tests compare each with `r/inst/extdata/reference/expected.json`.

## Changes that may be made without the maintainer's review

- Compatibility fixes for new versions of NumPy, Pillow or the R packages, as long as every test still passes unchanged.
- The HTML report layout, documentation and the site.

## Changes that always need the maintainer's review

- `ALGORITHMS.md`, `src/reproimage/hashing.py`, `src/reproimage/analysis.py`, `r/R/hashing.R`, `r/R/analysis.R`, `reference/generate.py` and `r/inst/extdata/reference/`. These define what the tool detects; a change is a new algorithm version.
- Workflows, `.maintenance.json`, `CODEOWNERS` and this file.

Tests are never weakened or deleted to make them pass.

## Principles

- Results describe visual relations, never misconduct. Every report keeps the expert-review notice.
- Python depends only on NumPy and Pillow; R only on png, jpeg, tiff, digest and jsonlite.
