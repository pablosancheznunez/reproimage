#' reproimage: integrity, provenance and reproducibility checks for scientific images
#'
#' Fingerprints scientific images and lists pairs that are identical (same
#' file or same pixels) or visually similar, including rotated, flipped and
#' re-contrasted copies, with a self-contained HTML report and an RO-Crate
#' provenance record. The algorithms are written down in a specification
#' (`ALGORITHMS.md` in the source repository) that this package and the
#' ReproImage Python tool implement independently; both are tested against the
#' same reference images.
#'
#' Results describe visual relations between images, never misconduct, and
#' always need expert review.
#'
#' Start with [ri_analyze()] and [ri_write()]; see `vignette("reproimage")`.
#'
#' @keywords internal
"_PACKAGE"
