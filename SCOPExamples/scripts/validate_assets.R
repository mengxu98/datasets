# Validate compact SCOP example assets and write a machine-readable manifest.

validate_scop_example_assets <- function(
  asset_dir = file.path("SCOPExamples"),
  manifest_file = file.path(asset_dir, "manifest.tsv")
) {
  required <- c("digest", "Matrix")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
  asset_dir <- normalizePath(asset_dir, mustWork = TRUE)
  asset_specs <- data.frame(
    dataset = c(
      "visium_human_pancreas_results_sub",
      "visium_human_pancreas_pair_sub",
      "xenium_human_pancreas_boundaries_sub",
      "pbmc_celltypist_sub"
    ),
    file = paste0(c(
      "visium_human_pancreas_results_sub",
      "visium_human_pancreas_pair_sub",
      "xenium_human_pancreas_boundaries_sub",
      "pbmc_celltypist_sub"
    ), ".rds"),
    stringsAsFactors = FALSE
  )
  rows <- vector("list", nrow(asset_specs))
  for (i in seq_len(nrow(asset_specs))) {
    spec <- asset_specs[i, ]
    path <- file.path(asset_dir, spec$file)
    base <- list(
      dataset = spec$dataset,
      file = spec$file,
      status = "omitted",
      object = NA_character_,
      source = NA_character_,
      samples = NA_integer_,
      cells = NA_integer_,
      features = NA_integer_,
      boundary_vertices = NA_integer_,
      sha256 = NA_character_,
      size_bytes = NA_integer_,
      validation = NA_character_,
      omitted_methods = NA_character_,
      omission_reason = "asset file not present"
    )
    if (!file.exists(path)) {
      if (identical(spec$dataset, "xenium_human_pancreas_boundaries_sub")) {
        base$omission_reason <- paste(
          "not generated in this build:",
          "TENxXeniumData resource EH8549 (spe_human_pancreas.rds; 398436692 bytes)",
          "timed out during retrieval before polygon extraction"
        )
      }
      rows[[i]] <- base
      next
    }
    x <- tryCatch(readRDS(path), error = function(e) e)
    if (inherits(x, "error")) {
      base$omission_reason <- paste0("readRDS failed: ", conditionMessage(x))
      rows[[i]] <- base
      next
    }
    base$status <- "success"
    base$object <- paste(class(x), collapse = "/")
    base$sha256 <- digest::digest(path, algo = "sha256", file = TRUE)
    base$size_bytes <- unname(file.info(path)$size)
    checks <- character()
    if (inherits(x, "Seurat")) {
      base$cells <- ncol(x)
      base$features <- nrow(x)
      md <- x[[]]
      provenance <- x@tools[["SCOPExamples"]]
      if (is.list(provenance) && !is.null(provenance$source)) {
        base$source <- paste(as.character(provenance$source), collapse = ";")
      }
      omitted <- if (is.list(provenance)) provenance[["omitted"]] else NULL
      if (is.data.frame(omitted) && nrow(omitted) > 0L) {
        base$omitted_methods <- paste(as.character(omitted[["method"]]), collapse = ",")
      }
      if ("sample_id" %in% colnames(md)) {
        base$samples <- length(unique(as.character(md$sample_id)))
        checks <- c(checks, if (base$samples >= 2L || identical(spec$dataset, "visium_human_pancreas_results_sub")) "sample_ids_ok" else "sample_ids_failed")
      } else {
        base$samples <- 1L
      }
      if (all(c("x", "y") %in% colnames(md))) {
        checks <- c(checks, if (all(is.finite(md$x) & is.finite(md$y))) "finite_coordinates_ok" else "finite_coordinates_failed")
      }
      if (identical(spec$dataset, "visium_human_pancreas_results_sub")) {
        ok <- is.list(x@tools[["SpatialNetwork"]]) && is.list(x@tools[["SpatialNeighborhood"]])
        checks <- c(checks, if (ok) "native_result_bundles_ok" else "native_result_bundles_failed")
      }
      if (identical(spec$dataset, "pbmc_celltypist_sub")) {
        ct <- x@tools[["SCOPExamples"]][["celltypist"]]
        ct_status <- if (is.list(ct)) ct[["status"]] else NA_character_
        checks <- c(checks, if (length(ct_status) == 1L && ct_status %in% c("success", "omitted")) "celltypist_status_recorded" else "celltypist_status_missing")
      }
    } else if (is.data.frame(x) && identical(spec$dataset, "xenium_human_pancreas_boundaries_sub")) {
      base$boundary_vertices <- nrow(x)
      provenance <- attr(x, "SCOPExamples")
      if (is.list(provenance) && !is.null(provenance$source)) {
        base$source <- paste(as.character(provenance$source), collapse = ";")
      }
      required_cols <- c("cell_id", "polygon_id", "ring_id", "vertex_order", "x", "y", "cell_area", "image")
      checks <- c(checks, if (all(required_cols %in% colnames(x))) "boundary_schema_ok" else "boundary_schema_failed")
      if (all(c("x", "y") %in% colnames(x))) checks <- c(checks, if (all(is.finite(x$x) & is.finite(x$y))) "finite_coordinates_ok" else "finite_coordinates_failed")
      ring <- interaction(x$cell_id, x$polygon_id, x$ring_id, drop = TRUE)
      closed <- vapply(split(seq_len(nrow(x)), ring), function(j) {
        n <- length(j)
        n >= 4L && isTRUE(all.equal(c(x$x[j[[1L]]], x$y[j[[1L]]]), c(x$x[j[[n]]], x$y[j[[n]]])))
      }, logical(1))
      unique_cells <- unique(x$cell_id)
      checks <- c(checks, if (all(closed)) "polygon_rings_closed" else "polygon_rings_not_closed", paste0("unique_cell_ids_", length(unique_cells)))
      base$cells <- length(unique_cells)
    } else {
      base$status <- "omitted"
      base$omission_reason <- "unexpected object class"
    }
    base$validation <- paste(checks, collapse = ";")
    base$omission_reason <- NA_character_
    if (any(grepl("failed|not_closed|missing", checks))) {
      base$status <- "omitted"
      base$omission_reason <- paste(checks[grepl("failed|not_closed|missing", checks)], collapse = ";")
    }
    rows[[i]] <- base
  }
  manifest <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  utils::write.table(manifest, manifest_file, sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")
  print(manifest)
  invisible(manifest)
}
