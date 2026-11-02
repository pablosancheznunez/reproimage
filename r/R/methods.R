category_text <- c(identical_file = "Identical files",
                   identical_pixels = "Identical pixels, different files",
                   similar = "Visually similar")

#' Inspect an image analysis
#'
#' `print()` lists the related pairs. `summary()` counts them by category.
#' `as.data.frame()` returns one row per related pair.
#'
#' @param x,object A `reproimage_result` from [ri_analyze()].
#' @param row.names,optional Ignored; present for compatibility.
#' @param ... Ignored.
#' @return `print()`: `x`, invisibly. `summary()` and `as.data.frame()`: a
#'   data frame.
#' @name reproimage_result
#' @examples
#' res <- ri_analyze(ri_example_dir())
#' print(res)
#' summary(res)
NULL

#' @rdname reproimage_result
#' @export
print.reproimage_result <- function(x, ...) {
  cat("ReproImage analysis\n")
  cat(length(x$images), " images, ", length(x$pairs), " related pairs (algorithm version ",
      x$tool$algorithm_version, ", thresholds dHash ", x$parameters$thresholds$dhash,
      " / pHash ", x$parameters$thresholds$phash, ")\n\n", sep = "")
  df <- as.data.frame(x)
  if (nrow(df)) {
    detail <- ifelse(df$category == "similar",
                     sprintf("%s, distances %d/%d", df$orientation, df$dhash_distance, df$phash_distance), "")
    width <- max(nchar(df$a))
    for (i in seq_len(nrow(df))) {
      cat(formatC(df$a[i], width = -width), "  ", formatC(df$category[i], width = -16), "  ", df$b[i],
          if (nzchar(detail[i])) paste0("  (", detail[i], ")"), "\n", sep = "")
    }
  } else {
    cat("No identical or similar pairs.\n")
  }
  cat("\nRequires expert review: visual relations, not evidence of misconduct.\n")
  invisible(x)
}

#' @rdname reproimage_result
#' @export
summary.reproimage_result <- function(object, ...) {
  df <- as.data.frame(object)
  data.frame(category = names(category_text),
             pairs = vapply(names(category_text), function(k) sum(df$category == k), 0L),
             row.names = NULL, stringsAsFactors = FALSE)
}

#' @rdname reproimage_result
#' @export
as.data.frame.reproimage_result <- function(x, row.names = NULL, optional = FALSE, ...) {
  if (!length(x$pairs)) {
    return(data.frame(a = character(), b = character(), category = character(), orientation = character(),
                      dhash_distance = integer(), phash_distance = integer(), stringsAsFactors = FALSE))
  }
  do.call(rbind, lapply(x$pairs, function(p) {
    data.frame(a = p$a, b = p$b, category = p$category,
               orientation = if (is.null(p$orientation)) NA_character_ else p$orientation,
               dhash_distance = as.integer(p$dhash_distance), phash_distance = as.integer(p$phash_distance),
               stringsAsFactors = FALSE)
  }))
}

#' @rdname reproimage_result
#' @export
ri_pairs <- function(x) as.data.frame.reproimage_result(x)
