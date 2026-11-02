# reproimage (R)

R implementation of [ReproImage](https://github.com/pablosancheznunez/reproimage).

```r
remotes::install_github("pablosancheznunez/reproimage", subdir = "r")
library(reproimage)
res <- ri_analyze("figures/")
ri_pairs(res)
ri_write(res, "report/")   # result.json, pairs.csv, ro-crate-metadata.json
```

Implements the written specification in `ALGORITHMS.md` and is tested against
the same reference images and expected results as the Python tool.
