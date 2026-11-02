# ReproImage

Integrity, provenance and reproducibility checks for scientific images, in Python and R.

Point it at a folder of figures and it lists identical files, identical pixels saved in another format (PNG vs TIFF), and visually similar images, including rotated, flipped and re-contrasted copies. Every analysis comes with an RO-Crate provenance record.

**Results need expert review.** ReproImage reports visual relations between images, never misconduct. A similar pair may be a legitimate reuse, a control shown twice, or an honest error.

Site and example report: <https://pablosancheznunez.github.io/reproimage/>

## Python

```bash
pip install git+https://github.com/pablosancheznunez/reproimage
reproimage analyze figures/ --out report/
```

Writes `report.html` (self-contained, side-by-side comparisons), `result.json`, `pairs.csv` and `ro-crate-metadata.json`. Depends only on NumPy and Pillow.

## R

```r
remotes::install_github("pablosancheznunez/reproimage", subdir = "r")
library(reproimage)
res <- ri_analyze("figures/")
ri_pairs(res)
ri_write(res, "report/")
```

Depends only on `png`, `jpeg`, `tiff`, `digest` and `jsonlite` (no ImageMagick).

## One specification, two implementations

The algorithms are written down in [`ALGORITHMS.md`](ALGORITHMS.md): decoding, grey level, a block resize that avoids library resampling, SHA-256 of files and pixels, dHash and pHash in eight orientations, and the pair rules. Python and R implement it independently and are tested against the same [reference dataset](reference/) and [expected results](reference/expected.json). If either drifts, CI fails.

## Known limits

- Hashes describe the whole image: a duplicated region inside an otherwise different image (such as one spliced gel lane, included in the reference set) is not detected yet.
- Strong crops or resizing can push similar images past the threshold.
- 16-bit colour images are analysed but are not part of the conformance tests.

## Maintenance

Maintained with [research-tools-ops](https://github.com/pablosancheznunez/research-tools-ops): Dependabot, automatic repair proposals when CI fails, and a monthly release when something changed. Changes to the algorithms, thresholds, reference images or expected results always need the maintainer's approval.

## Tests

```bash
pip install -e .[test] && pytest
Rscript -e 'devtools::test("r")'
```

## Citation and license

See [`CITATION.cff`](CITATION.cff). Code: MIT. Reference images: CC BY 4.0.
