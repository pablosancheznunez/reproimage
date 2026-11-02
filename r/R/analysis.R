#' Fingerprint one image
#'
#' @param path Image file.
#' @param name Name recorded in the result (default: the file name).
#' @return A list with hashes, size and format.
#' @export
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
#' @param a,b Fingerprints from [ri_fingerprint()].
#' @param thresholds Maximum dHash and pHash distances for `"similar"`.
#' @return `NULL` if the images are different, otherwise a list with the
#'   category, orientation and distances (ALGORITHMS.md section 7).
#' @export
ri_compare <- function(a, b, thresholds = list(dhash = 10L, phash = 10L)) {
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

#' Analyze a folder of images
#'
#' Fingerprints every PNG, TIFF and JPEG file (recursively) and lists the pairs
#' that are identical or visually similar. Results describe visual relations,
#' not misconduct, and need expert review.
#'
#' @param folder Folder with images.
#' @param thresholds Maximum dHash and pHash distances for `"similar"`.
#' @return A result list with the same structure as the Python tool's
#'   `result.json` (schema `reproimage-result/1`).
#' @export
#' @examples
#' \dontrun{
#' res <- ri_analyze("figures/")
#' ri_pairs(res)
#' }
ri_analyze <- function(folder, thresholds = list(dhash = 10L, phash = 10L)) {
  files <- list.files(folder, recursive = TRUE)
  files <- files[tolower(tools::file_ext(files)) %in% extensions]
  files <- sort(files, method = "radix")
  images <- lapply(files, function(f) ri_fingerprint(file.path(folder, f), name = f))
  pairs <- list()
  n <- length(images)
  if (n > 1) for (i in 1:(n - 1)) for (j in (i + 1):n) {
    res <- ri_compare(images[[i]], images[[j]], thresholds)
    if (!is.null(res)) pairs[[length(pairs) + 1]] <- c(list(a = images[[i]]$name, b = images[[j]]$name), res)
  }
  list(
    schema = "reproimage-result/1",
    tool = list(name = "reproimage-r", version = as.character(utils::packageVersion("reproimage")),
                algorithm_version = algorithm_version),
    parameters = list(thresholds = thresholds),
    images = lapply(images, function(im) im[names(im) != "variants"]),
    pairs = pairs
  )
}

#' Related pairs as a data frame
#'
#' @param result A result from [ri_analyze()].
#' @return A data frame with one row per related pair.
#' @export
ri_pairs <- function(result) {
  if (!length(result$pairs)) {
    return(data.frame(a = character(), b = character(), category = character(), orientation = character(),
                      dhash_distance = integer(), phash_distance = integer()))
  }
  do.call(rbind, lapply(result$pairs, function(p) {
    data.frame(a = p$a, b = p$b, category = p$category,
               orientation = if (is.null(p$orientation)) NA_character_ else p$orientation,
               dhash_distance = p$dhash_distance, phash_distance = p$phash_distance)
  }))
}

#' Write a result with its provenance
#'
#' Writes `result.json`, `pairs.csv` and an RO-Crate `ro-crate-metadata.json`
#' describing the analysis.
#'
#' @param result A result from [ri_analyze()].
#' @param out_dir Output folder.
#' @return The output folder, invisibly.
#' @export
ri_write <- function(result, out_dir) {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  jsonlite::write_json(result, file.path(out_dir, "result.json"), auto_unbox = TRUE, null = "null", pretty = TRUE, digits = NA)
  utils::write.csv(ri_pairs(result), file.path(out_dir, "pairs.csv"), row.names = FALSE)
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  files <- lapply(result$images, function(im) list(`@id` = paste0("input/", im$name), `@type` = "File", name = im$name, sha256 = im$file_sha256))
  graph <- c(list(
    list(`@id` = "ro-crate-metadata.json", `@type` = "CreativeWork",
         conformsTo = list(`@id` = "https://w3id.org/ro/crate/1.1"), about = list(`@id` = "./")),
    list(`@id` = "./", `@type` = "Dataset", name = "ReproImage analysis", datePublished = now,
         hasPart = list(list(`@id` = "result.json"), list(`@id` = "pairs.csv")), mentions = list(`@id` = "#analysis")),
    list(`@id` = "#analysis", `@type` = "CreateAction", name = "Fingerprint images and classify pairs",
         instrument = list(`@id` = "#reproimage"), endTime = now,
         object = lapply(files, function(f) list(`@id` = f$`@id`)),
         result = list(list(`@id` = "result.json"), list(`@id` = "pairs.csv"))),
    list(`@id` = "#reproimage", `@type` = "SoftwareApplication", name = "ReproImage (R)",
         version = result$tool$version, url = "https://github.com/pablosancheznunez/reproimage",
         description = paste("Algorithm version", result$tool$algorithm_version))
  ), files)
  jsonlite::write_json(list(`@context` = "https://w3id.org/ro/crate/1.1/context", `@graph` = graph),
                       file.path(out_dir, "ro-crate-metadata.json"), auto_unbox = TRUE, pretty = TRUE)
  invisible(out_dir)
}
