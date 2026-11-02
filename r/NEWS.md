# reproimage 0.1.0

* First release, prepared for CRAN.
* `ri_analyze()` fingerprints a folder or a set of files (PNG, TIFF 8/16-bit,
  JPEG) and classifies pairs as identical files, identical pixels or visually
  similar in any of eight orientations.
* `ri_write()` writes `result.json`, `pairs.csv`, a self-contained
  `report.html` and an RO-Crate provenance record.
* `print()`, `summary()` and `as.data.frame()` methods for results.
* Algorithm version 1, identical to the ReproImage Python tool on the bundled
  reference images (`ri_example_dir()`).
