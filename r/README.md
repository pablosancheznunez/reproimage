# reproimage (R)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23881635.svg)](https://doi.org/10.5281/zenodo.23881635)

Integrity, provenance and reproducibility checks for scientific images.

```r
# install.packages("remotes")
remotes::install_github("pablosancheznunez/reproimage", subdir = "r")

library(reproimage)
res <- ri_analyze("figures/")   # or ri_example_dir() to try it
res                              # related pairs
ri_write(res, "report/")         # result.json, pairs.csv, report.html, RO-Crate
```

Implements the written specification in `ALGORITHMS.md` and gives the same
results as the Python tool on the bundled reference images. Results describe
visual relations, never misconduct. See `vignette("reproimage")`; cite with
`citation("reproimage")`. Dependencies: `png`, `jpeg`, `tiff`, `digest`,
`jsonlite`.
