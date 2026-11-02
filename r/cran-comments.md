## Submission

First submission of reproimage.

## Test environments

* GitHub Actions: Ubuntu (R devel, release, oldrel-1), macOS (release),
  Windows (release).
* Local: Windows 11, R 4.6.2.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes for CRAN

* Examples, tests and the vignette use twelve small synthetic images
  (224 KB in total) shipped in `inst/extdata/reference`; no internet access
  is needed.
* Examples write only to `tempdir()` and clean up after themselves.
