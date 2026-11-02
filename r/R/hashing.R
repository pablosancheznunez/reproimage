# Decoding, hashes and orientations, exactly as specified in ALGORITHMS.md.
# Mirrors src/reproimage/io.py and hashing.py; both are tested against
# the same reference images and expected results.

algorithm_version <- 1L
eps <- 1e-6
orientations <- c("identity", "rot90", "rot180", "rot270",
                  "flip", "flip_rot90", "flip_rot180", "flip_rot270")
extensions <- c("png", "tif", "tiff", "jpg", "jpeg")

#' Read an image as specified in ALGORITHMS.md
#'
#' @param path Path to a PNG, TIFF or JPEG file.
#' @return A list with `rgb` (an H x W x 3 array on a 0-255 scale), `width`,
#'   `height`, `format` and `bit_depth`.
#' @export
ri_read <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "png") {
    v <- png::readPNG(path, info = TRUE)
    depth <- attr(v, "info")$bit.depth
    format <- "PNG"
  } else if (ext %in% c("tif", "tiff")) {
    v <- tiff::readTIFF(path, info = TRUE)
    depth <- attr(v, "bits.per.sample")
    format <- "TIFF"
  } else if (ext %in% c("jpg", "jpeg")) {
    v <- jpeg::readJPEG(path)
    depth <- 8L
    format <- "JPEG"
  } else {
    stop("Unsupported image format: ", path, call. = FALSE)
  }
  if (is.null(depth) || is.na(depth)) depth <- 8L
  max_level <- 2^depth - 1
  levels <- round(as.numeric(v) * max_level)
  value <- if (depth == 16) levels / 257 else levels * (255 / max_level)
  dim(value) <- dim(v)
  if (length(dim(value)) == 2) {
    rgb <- array(value, c(dim(value), 3))
  } else if (dim(value)[3] <= 2) {
    rgb <- array(value[, , 1], c(dim(value)[1:2], 3))
  } else {
    rgb <- value[, , 1:3, drop = FALSE]
  }
  list(rgb = rgb, width = dim(rgb)[2], height = dim(rgb)[1], format = format, bit_depth = as.integer(depth))
}

ri_grey <- function(rgb) (0.299 * rgb[, , 1] + 0.587 * rgb[, , 2]) + 0.114 * rgb[, , 3]

block_resize <- function(g, h, w) {
  H <- nrow(g)
  W <- ncol(g)
  out <- matrix(0, h, w)
  for (i in 0:(h - 1)) {
    r0 <- (i * H) %/% h
    r1 <- max(((i + 1) * H) %/% h, r0 + 1)
    for (j in 0:(w - 1)) {
      c0 <- (j * W) %/% w
      c1 <- max(((j + 1) * W) %/% w, c0 + 1)
      out[i + 1, j + 1] <- mean(g[(r0 + 1):r1, (c0 + 1):c1])
    }
  }
  out
}

bits_to_hex <- function(bits) {
  nibbles <- matrix(as.integer(bits), nrow = 4)
  paste(sprintf("%x", colSums(nibbles * c(8L, 4L, 2L, 1L))), collapse = "")
}

hex_to_bits <- function(hex) {
  vals <- strtoi(strsplit(hex, "")[[1]], 16L)
  as.vector(vapply(vals, function(v) as.integer(intToBits(v))[4:1], integer(4)))
}

ri_dhash <- function(g) {
  s <- block_resize(g, 8, 9)
  bits_to_hex(as.vector(t((s[, 2:9] - s[, 1:8]) > eps)))
}

dct_matrix <- outer(0:31, 0:31, function(k, n) cos(pi * (2 * n + 1) * k / 64))

ri_phash <- function(g) {
  s <- block_resize(g, 32, 32)
  d <- dct_matrix %*% s %*% t(dct_matrix)
  low <- as.vector(t(d[1:8, 1:8]))
  m <- stats::median(low[-1])
  bits_to_hex((low - m) > eps)
}

#' Hamming distance between two 64-bit hashes
#'
#' @param a,b Hashes as 16 hexadecimal characters.
#' @return An integer between 0 and 64.
#' @export
ri_hamming <- function(a, b) sum(hex_to_bits(a) != hex_to_bits(b))

rot90 <- function(m) t(m)[ncol(m):1, , drop = FALSE]

ri_orient <- function(g, name) {
  if (startsWith(name, "flip")) g <- g[, ncol(g):1, drop = FALSE]
  base <- sub("^flip_?", "", name)
  turns <- c(identity = 0, rot90 = 1, rot180 = 2, rot270 = 3)[[if (base == "") "identity" else base]]
  for (k in seq_len(turns)) g <- rot90(g)
  g
}

ri_pixel_sha256 <- function(rgb) {
  data <- pmin(pmax(floor(rgb + 0.5), 0), 255)
  header <- charToRaw(sprintf("%dx%d\n", dim(rgb)[1], dim(rgb)[2]))
  body <- as.raw(as.vector(aperm(data, c(3, 2, 1))))
  digest::digest(c(header, body), algo = "sha256", serialize = FALSE)
}

ri_file_sha256 <- function(path) digest::digest(file = path, algo = "sha256")
