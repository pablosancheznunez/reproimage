ref <- ri_example_dir()
expected <- jsonlite::fromJSON(file.path(dirname(ref), "expected.json"), simplifyVector = FALSE)

canonical <- function(x) {
  jsonlite::fromJSON(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA),
                     simplifyVector = FALSE)
}

test_that("results match the Python implementation on the reference dataset", {
  res <- ri_analyze(ref)
  expect_s3_class(res, "reproimage_result")
  keys <- c("name", "file_sha256", "pixel_sha256", "width", "height", "dhash", "phash")
  got <- list(
    algorithm_version = res$tool$algorithm_version,
    thresholds = res$parameters$thresholds,
    images = lapply(res$images, function(im) im[keys]),
    pairs = unclass(res)$pairs
  )
  expect_equal(canonical(got), expected)
})

test_that("a vector of files gives the same pairs as the folder", {
  files <- file.path(ref, c("gel_a.png", "gel_a_flip.png", "gel_b.png"))
  res <- ri_analyze(files)
  df <- as.data.frame(res)
  expect_equal(nrow(df), 1)
  expect_equal(df$orientation, "flip")
  expect_error(ri_analyze(file.path(ref, "missing.png")), "not found")
})

test_that("bit helpers", {
  expect_equal(bits_to_hex(c(1, rep(0, 63))), "8000000000000000")
  expect_equal(ri_hamming("ffffffffffffffff", "0000000000000000"), 64)
  expect_equal(ri_hamming("8000000000000001", "8000000000000000"), 1)
})

test_that("orientations follow numpy conventions", {
  g <- matrix(c(1, 3, 2, 4), 2)  # rows: (1, 2), (3, 4)
  expect_equal(ri_orient(g, "rot90"), matrix(c(2, 1, 4, 3), 2))
  expect_equal(ri_orient(g, "flip"), matrix(c(2, 4, 1, 3), 2))
  expect_equal(ri_orient(g, "flip_rot90"), matrix(c(1, 2, 3, 4), 2))
})

test_that("uniform image has an all-zero dHash", {
  expect_equal(ri_dhash(matrix(77, 40, 40)), "0000000000000000")
})

test_that("16-bit images are scaled to 0-255", {
  img <- ri_read(file.path(ref, "cells_a_16bit.tif"))
  expect_equal(img$bit_depth, 16L)
  expect_true(max(img$rgb) <= 255 && min(img$rgb) >= 0)
})

test_that("thresholds are validated and change the result", {
  expect_error(ri_analyze(ref, thresholds = list(dhash = 100, phash = 1)), "between 0 and 64")
  strict <- ri_analyze(ref, thresholds = list(dhash = 0, phash = 0))
  expect_lt(nrow(as.data.frame(strict)), nrow(as.data.frame(ri_analyze(ref))))
})

test_that("methods and outputs", {
  res <- ri_analyze(ref)
  expect_output(print(res), "Requires expert review")
  s <- summary(res)
  expect_equal(sum(s$pairs), length(res$pairs))
  out <- file.path(tempdir(), "reproimage-test")
  on.exit(unlink(out, recursive = TRUE))
  ri_write(res, out)
  expect_true(all(file.exists(file.path(out, c("result.json", "pairs.csv", "report.html", "ro-crate-metadata.json")))))
  html <- paste(readLines(file.path(out, "report.html"), warn = FALSE), collapse = "\n")
  expect_match(html, "data:image/png;base64,")
  expect_match(html, "Requires expert review")
  crate <- jsonlite::fromJSON(file.path(out, "ro-crate-metadata.json"), simplifyVector = FALSE)
  action <- Filter(function(e) identical(e[["@type"]], "CreateAction"), crate[["@graph"]])[[1]]
  expect_length(action$object, 12)
})
