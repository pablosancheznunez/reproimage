ref <- test_path("reference")

canonical <- function(x) {
  jsonlite::fromJSON(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA),
                     simplifyVector = FALSE)
}

test_that("results match the Python implementation on the reference dataset", {
  res <- ri_analyze(file.path(ref, "images"))
  keys <- c("name", "file_sha256", "pixel_sha256", "width", "height", "dhash", "phash")
  got <- list(
    algorithm_version = res$tool$algorithm_version,
    thresholds = res$parameters$thresholds,
    images = lapply(res$images, function(im) im[keys]),
    pairs = res$pairs
  )
  expected <- jsonlite::fromJSON(file.path(ref, "expected.json"), simplifyVector = FALSE)
  expect_equal(canonical(got), expected)
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

test_that("writing produces JSON, CSV and RO-Crate", {
  out <- tempfile("reproimage-")
  res <- ri_analyze(file.path(ref, "images"))
  ri_write(res, out)
  expect_true(all(file.exists(file.path(out, c("result.json", "pairs.csv", "ro-crate-metadata.json")))))
  expect_equal(nrow(ri_pairs(res)), length(res$pairs))
})
