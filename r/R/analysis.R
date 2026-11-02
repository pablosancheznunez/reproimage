default_thresholds <- list(dhash = 10L, phash = 10L)

check_thresholds <- function(thresholds) {
  if (!is.list(thresholds) || !all(c("dhash", "phash") %in% names(thresholds)) ||
      !all(vapply(thresholds[c("dhash", "phash")], function(v) is.numeric(v) && length(v) == 1 && v >= 0 && v <= 64, TRUE))) {
    stop("`thresholds` must be a list with `dhash` and `phash` between 0 and 64.", call. = FALSE)
  }
  list(dhash = as.integer(thresholds$dhash), phash = as.integer(thresholds$phash))
}

#' Fingerprint one image
#'
#' Computes the SHA-256 of the file and of its decoded pixels, and the
#' difference hash (dHash) and perceptual hash (pHash) of the image in eight
#' orientations, as specified in the package's `ALGORITHMS.md`.
#'
#' @param path Image file (PNG, TIFF or JPEG).
#' @param name Name recorded in the result.
#' @return A list with `name`, `file_sha256`, `pixel_sha256`, `width`,
#'   `height`, `dhash`, `phash`, `format`, `bit_depth` and `variants` (the
#'   hashes of every orientation).
#' @export
#' @examples
#' f <- file.path(ri_example_dir(), "gel_a.png")
#' fp <- ri_fingerprint(f)
#' fp[c("name", "width", "height", "dhash", "phash")]
ri_fingerprint <- function(path, name = basename(path)) {
  img <- ri_read(path)
  g <- ri_grey(img$rgb)
  variants <- lapply(orientations, function(o) {
    go <- ri_orient(g, o)
    list(dhash = ri_dhash(go), phash = ri_phash(go))
  })
  names(variants) <- orientations
  list(name = name, file_sha256 = ri_file_sha256(path), pixel_sha256 = ri_pixel_sha256(img$rgb),
       width = img$width, height = img$height,
       dhash = variants$identity$dhash, phash = variants$identity$phash,
       format = img$format, bit_depth = img$bit_depth, variants = variants)
}

#' Compare two fingerprints
#'
#' Applies the pair rules of `ALGORITHMS.md`: identical files, identical
#' pixels, or visual similarity in any of eight orientations within the
#' distance thresholds.
#'
#' @param a,b Fingerprints from [ri_fingerprint()].
#' @param thresholds Maximum dHash and pHash Hamming distances (0 to 64) for
#'   a pair to count as `"similar"`.
#' @return `NULL` if the images are not related, otherwise a list with
#'   `category`, `orientation`, `dhash_distance` and `phash_distance`.
#' @export
#' @examples
#' d <- ri_example_dir()
#' a <- ri_fingerprint(file.path(d, "gel_a.png"))
#' b <- ri_fingerprint(file.path(d, "gel_a_rot90.png"))
#' ri_compare(a, b)
ri_compare <- function(a, b, thresholds = default_thresholds) {
  thresholds <- check_thresholds(thresholds)
  same <- function(category) list(category = category, orientation = NULL, dhash_distance = 0L, phash_distance = 0L)
  if (a$file_sha256 == b$file_sha256) return(same("identical_file"))
  if (a$pixel_sha256 == b$pixel_sha256) return(same("identical_pixels"))
  best <- NULL
  for (o in orientations) {
    d <- ri_hamming(a$dhash, b$variants[[o]]$dhash)
    p <- ri_hamming(a$phash, b$variants[[o]]$phash)
    if (d <= thresholds$dhash && p <= thresholds$phash && (is.null(best) || d + p < best$d + best$p)) {
      best <- list(o = o, d = d, p = p)
    }
  }
  if (is.null(best)) return(NULL)
  list(category = "similar", orientation = best$o, dhash_distance = best$d, phash_distance = best$p)
}

#' Analyse a set of images
#'
#' Fingerprints every image and lists the pairs that are identical or visually
#' similar. Results describe visual relations between images, never
#' misconduct: a similar pair may be a legitimate reuse, a control shown twice
#' or an honest error, and always needs expert review.
#'
#' @param x A folder (searched recursively for PNG, TIFF and JPEG files) or a
#'   character vector of image files.
#' @param thresholds Maximum dHash and pHash distances for `"similar"`.
#' @param progress Show progress messages.
#' @return An object of class `reproimage_result`, with the structure of the
#'   Python tool's `result.json` (schema `reproimage-result/1`). It has
#'   `print()`, `summary()` and `as.data.frame()` methods and can be written
#'   with [ri_write()].
#' @export
#' @examples
#' res <- ri_analyze(ri_example_dir())
#' res
#' head(as.data.frame(res))
ri_analyze <- function(x, thresholds = default_thresholds, progress = FALSE) {
  thresholds <- check_thresholds(thresholds)
  if (length(x) == 1 && dir.exists(x)) {
    root <- normalizePath(x, winslash = "/")
    names <- list.files(x, recursive = TRUE)
    names <- sort(names[tolower(tools::file_ext(names)) %in% extensions], method = "radix")
    paths <- file.path(root, names)
  } else {
    missing <- x[!file.exists(x)]
    if (length(missing)) stop("Files not found: ", paste(missing, collapse = ", "), call. = FALSE)
    paths <- normalizePath(x, winslash = "/")
    names <- basename(paths)
    if (anyDuplicated(names)) stop("File names must be unique; pass a folder instead.", call. = FALSE)
    o <- order(names, method = "radix")
    paths <- paths[o]
    names <- names[o]
    root <- NULL
  }
  if (!length(paths)) stop("No PNG, TIFF or JPEG images found.", call. = FALSE)
  images <- lapply(seq_along(paths), function(i) {
    if (progress) message(sprintf("[%d/%d] %s", i, length(paths), names[i]))
    ri_fingerprint(paths[i], name = names[i])
  })
  pairs <- list()
  n <- length(images)
  if (n > 1) for (i in 1:(n - 1)) for (j in (i + 1):n) {
    res <- ri_compare(images[[i]], images[[j]], thresholds)
    if (!is.null(res)) pairs[[length(pairs) + 1]] <- c(list(a = images[[i]]$name, b = images[[j]]$name), res)
  }
  result <- list(
    schema = "reproimage-result/1",
    tool = list(name = "reproimage-r", version = as.character(utils::packageVersion("reproimage")),
                algorithm_version = algorithm_version),
    parameters = list(thresholds = thresholds),
    images = lapply(images, function(im) im[names(im) != "variants"]),
    pairs = pairs
  )
  structure(result, class = "reproimage_result", paths = stats::setNames(paths, names))
}

#' Folder with the reference images
#'
#' Twelve synthetic gel and fluorescence images with known relations (an exact
#' copy, the same pixels saved as TIFF, rotated, flipped and re-contrasted
#' versions, a spliced lane and unrelated negatives). The expected results are
#' in `reference/expected.json` next to the folder; the Python and R
#' implementations must reproduce them exactly.
#'
#' @return The path of the folder.
#' @export
#' @examples
#' list.files(ri_example_dir())
ri_example_dir <- function() system.file("extdata", "reference", "images", package = "reproimage", mustWork = TRUE)
