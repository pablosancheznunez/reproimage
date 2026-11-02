#' Write a result, its provenance and an HTML report
#'
#' Writes four files to `out_dir`:
#'
#' * `result.json`: the full result (schema `reproimage-result/1`);
#' * `pairs.csv`: one row per related pair;
#' * `report.html`: a self-contained report with side-by-side thumbnails;
#' * `ro-crate-metadata.json`: an RO-Crate 1.1 record of the analysis
#'   (inputs with their checksums, tool version and parameters), compatible
#'   with W3C PROV.
#'
#' @param result A `reproimage_result` from [ri_analyze()].
#' @param out_dir Output folder; created if needed.
#' @return The output folder, invisibly.
#' @export
#' @examples
#' res <- ri_analyze(ri_example_dir())
#' out <- file.path(tempdir(), "reproimage-example")
#' ri_write(res, out)
#' list.files(out)
#' unlink(out, recursive = TRUE)
ri_write <- function(result, out_dir) {
  if (!inherits(result, "reproimage_result")) stop("`result` must come from ri_analyze().", call. = FALSE)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  jsonlite::write_json(unclass(result), file.path(out_dir, "result.json"), auto_unbox = TRUE,
                       null = "null", na = "null", pretty = TRUE, digits = NA)
  utils::write.csv(as.data.frame(result), file.path(out_dir, "pairs.csv"), row.names = FALSE)
  write_html(result, file.path(out_dir, "report.html"))
  write_ro_crate(result, out_dir)
  invisible(out_dir)
}

utc_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

thumbnail <- function(path, size = 220) {
  rgb <- ri_read(path)$rgb
  h <- dim(rgb)[1]
  w <- dim(rgb)[2]
  scale <- max(1, ceiling(max(h, w) / size))
  if (scale > 1) {
    nh <- h %/% scale
    nw <- w %/% scale
    small <- array(0, c(nh, nw, 3))
    for (k in 1:3) small[, , k] <- block_resize(rgb[, , k], nh, nw)
    rgb <- small
  }
  raw <- png::writePNG(pmin(pmax(rgb / 255, 0), 1))
  paste0("data:image/png;base64,", jsonlite::base64_enc(raw))
}

write_html <- function(result, path) {
  paths <- attr(result, "paths")
  thumbs <- if (is.null(paths)) list() else lapply(paths, thumbnail)
  img <- function(name) {
    if (is.null(thumbs[[name]])) return("")
    sprintf('<img src="%s" alt="">', thumbs[[name]])
  }
  pairs <- vapply(result$pairs, function(p) {
    detail <- if (p$category == "similar") {
      sprintf("orientation %s, dHash distance %d, pHash distance %d", p$orientation, p$dhash_distance, p$phash_distance)
    } else ""
    sprintf(paste0('<article class="pair"><h3>%s</h3><p class="meta">%s</p><div class="sbs">',
                   '<figure>%s<figcaption>%s</figcaption></figure><figure>%s<figcaption>%s</figcaption></figure></div></article>'),
            category_text[[p$category]], detail, img(p$a), esc(p$a), img(p$b), esc(p$b))
  }, "")
  images <- vapply(result$images, function(im) {
    sprintf("<tr><td>%s</td><td>%d&times;%d</td><td>%s, %d-bit</td><td><code>%s&hellip;</code></td><td><code>%s</code></td></tr>",
            esc(im$name), im$width, im$height, im$format, im$bit_depth, substr(im$file_sha256, 1, 16), im$dhash)
  }, "")
  css <- paste(
    ":root{--bg:#fbfaf8;--surface:#fff;--text:#1d1c1a;--muted:#5f5c57;--line:#e2dfda;--warn:#9a6400;color-scheme:light dark}",
    "@media (prefers-color-scheme:dark){:root{--bg:#171716;--surface:#211f1e;--text:#ece9e4;--muted:#a7a29b;--line:#3a3734;--warn:#f0b44c}}",
    "body{margin:0;background:var(--bg);color:var(--text);font:16px/1.5 system-ui,sans-serif}",
    "main{max-width:960px;margin:0 auto;padding:24px 16px 48px}",
    ".caveat{border-left:4px solid var(--warn);background:var(--surface);padding:12px 16px}",
    ".pair{background:var(--surface);border:1px solid var(--line);border-radius:8px;padding:12px 16px;margin:12px 0}",
    ".pair h3{margin:0;font-size:1rem}.sbs{display:flex;gap:16px;flex-wrap:wrap}figure{margin:0}",
    "figcaption,.meta{color:var(--muted);font-size:.85rem}",
    "img{max-width:220px;height:auto;image-rendering:pixelated;border:1px solid var(--line)}",
    ".scroll{overflow-x:auto}table{border-collapse:collapse;font-size:.85rem;width:100%}",
    "td,th{text-align:left;border-bottom:1px solid var(--line);padding:4px 8px}")
  page <- paste0(
    '<!doctype html><html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1"><title>ReproImage report</title>',
    "<style>", css, "</style></head><body><main><h1>ReproImage report</h1>",
    sprintf('<p class="meta">%d images &middot; %d related pairs &middot; reproimage (R) %s, algorithm version %d &middot; thresholds dHash %d, pHash %d</p>',
            length(result$images), length(result$pairs), result$tool$version, result$tool$algorithm_version,
            result$parameters$thresholds$dhash, result$parameters$thresholds$phash),
    '<div class="caveat"><strong>Requires expert review.</strong> These are visual relations between images, ',
    "not evidence of misconduct. A similar pair may be a legitimate reuse, a control shown twice, or an error.</div>",
    "<h2>Related pairs</h2>", if (length(pairs)) paste(pairs, collapse = "") else "<p>No identical or similar pairs were found.</p>",
    '<h2>Images</h2><div class="scroll"><table><tr><th>File</th><th>Size</th><th>Format</th><th>SHA-256</th><th>dHash</th></tr>',
    paste(images, collapse = ""), "</table></div></main></body></html>\n")
  writeLines(page, path, useBytes = TRUE)
}

write_ro_crate <- function(result, out_dir) {
  now <- utc_now()
  outputs <- list(list(`@id` = "result.json"), list(`@id` = "pairs.csv"), list(`@id` = "report.html"))
  files <- lapply(result$images, function(im) {
    list(`@id` = paste0("input/", im$name), `@type` = "File", name = im$name, sha256 = im$file_sha256)
  })
  graph <- c(list(
    list(`@id` = "ro-crate-metadata.json", `@type` = "CreativeWork",
         conformsTo = list(`@id` = "https://w3id.org/ro/crate/1.1"), about = list(`@id` = "./")),
    list(`@id` = "./", `@type` = "Dataset", name = "ReproImage analysis", datePublished = now,
         hasPart = outputs, mentions = list(`@id` = "#analysis")),
    list(`@id` = "#analysis", `@type` = "CreateAction", name = "Fingerprint images and classify pairs",
         instrument = list(`@id` = "#reproimage"), endTime = now,
         object = lapply(files, function(f) list(`@id` = f$`@id`)), result = outputs,
         description = paste0("Parameters: ", jsonlite::toJSON(result$parameters, auto_unbox = TRUE))),
    list(`@id` = "#reproimage", `@type` = "SoftwareApplication", name = "reproimage (R)",
         version = result$tool$version, url = "https://github.com/pablosancheznunez/reproimage",
         description = paste("Algorithm version", result$tool$algorithm_version)),
    list(`@id` = "result.json", `@type` = "File", encodingFormat = "application/json"),
    list(`@id` = "pairs.csv", `@type` = "File", encodingFormat = "text/csv"),
    list(`@id` = "report.html", `@type` = "File", encodingFormat = "text/html")
  ), files)
  jsonlite::write_json(list(`@context` = "https://w3id.org/ro/crate/1.1/context", `@graph` = graph),
                       file.path(out_dir, "ro-crate-metadata.json"), auto_unbox = TRUE, pretty = TRUE)
}
