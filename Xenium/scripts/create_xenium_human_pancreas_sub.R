# Prepare a compact Xenium human pancreas example for scop.
#
# The script writes:
#   Xenium/xenium_human_pancreas_sub.rds
#   Xenium/manifest.tsv

create_xenium_human_pancreas_sub <- function(
  source_rds = NULL,
  output_dir = file.path("Xenium"),
  n_cells = 3000,
  dataset = "xenium_human_pancreas_sub",
  seed = 98
) {
  required <- c(
    "TENxXeniumData",
    "SpatialExperiment",
    "SummarizedExperiment",
    "Seurat",
    "SeuratObject",
    "Matrix",
    "digest"
  )
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing, collapse = ", "),
      ". Install them before running this script.",
      call. = FALSE
    )
  }

  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  message("Loading TENxXeniumData human pancreas source object...")
  source_object <- if (!is.null(source_rds)) {
    message("Using local source RDS: ", normalizePath(source_rds, mustWork = FALSE))
    readRDS(source_rds)
  } else {
    TENxXeniumData::sfe_human_pancreas()
  }

  counts <- SummarizedExperiment::assay(source_object, "counts")
  counts <- as(counts, "dgCMatrix")
  coords <- SpatialExperiment::spatialCoords(source_object)
  coords <- as.data.frame(coords)
  if (ncol(coords) < 2) {
    stop("The source object must have at least two spatial coordinate columns.", call. = FALSE)
  }
  colnames(coords)[1:2] <- c("x", "y")

  cell_ids <- colnames(counts)
  if (is.null(cell_ids)) {
    cell_ids <- paste0("cell_", seq_len(ncol(counts)))
    colnames(counts) <- cell_ids
  }
  row_ids <- rownames(counts)
  if (is.null(row_ids)) {
    row_ids <- paste0("gene_", seq_len(nrow(counts)))
    rownames(counts) <- row_ids
  }
  rownames(coords) <- cell_ids

  n_count <- Matrix::colSums(counts)
  finite_coords <- is.finite(coords[["x"]]) & is.finite(coords[["y"]])
  eligible <- which(finite_coords & n_count > 0)
  if (length(eligible) == 0) {
    stop("No source cells have finite coordinates and non-zero counts.", call. = FALSE)
  }

  set.seed(seed)
  xy <- coords[eligible, c("x", "y"), drop = FALSE]
  center <- stats::setNames(vapply(xy, stats::median, numeric(1), na.rm = TRUE), c("x", "y"))
  dist_to_center <- (xy[["x"]] - center[["x"]])^2 + (xy[["y"]] - center[["y"]])^2
  selected <- eligible[order(dist_to_center, seq_along(dist_to_center))]
  selected <- selected[seq_len(min(n_cells, length(selected)))]
  selected_cells <- cell_ids[selected]

  counts_sub <- counts[, selected_cells, drop = FALSE]
  keep_features <- Matrix::rowSums(counts_sub) > 0
  counts_sub <- counts_sub[keep_features, , drop = FALSE]

  meta <- as.data.frame(SummarizedExperiment::colData(source_object)[selected_cells, , drop = FALSE])
  meta[["x"]] <- coords[selected_cells, "x"]
  meta[["y"]] <- coords[selected_cells, "y"]
  meta[["platform"]] <- "10x Xenium"
  meta[["source_dataset"]] <- "TENxXeniumData::sfe_human_pancreas"
  meta[["nCount_Xenium"]] <- Matrix::colSums(counts_sub)
  meta[["nFeature_Xenium"]] <- Matrix::colSums(counts_sub > 0)

  xenium_human_pancreas_sub <- Seurat::CreateSeuratObject(
    counts = counts_sub,
    assay = "Xenium",
    meta.data = meta
  )
  xenium_human_pancreas_sub@tools[["TENxXeniumData"]] <- list(
    source = "TENxXeniumData::sfe_human_pancreas()",
    source_url = "https://bioconductor.posit.co/packages/release/data/experiment/html/TENxXeniumData.html",
    source_experimenthub_id = "EH8550",
    source_object_class = class(source_object),
    tenxxeniumdata_version = as.character(utils::packageVersion("TENxXeniumData")),
    build_date = as.character(Sys.Date()),
    selection = list(
      strategy = "closest cells to the median spatial coordinate after filtering finite coordinates and non-zero counts",
      requested_cells = n_cells,
      retained_cells = ncol(xenium_human_pancreas_sub),
      retained_features = nrow(xenium_human_pancreas_sub),
      seed = seed
    )
  )

  rds_file <- file.path(output_dir, paste0(dataset, ".rds"))
  saveRDS(xenium_human_pancreas_sub, rds_file, compress = "xz")
  sha <- digest::digest(rds_file, algo = "sha256", file = TRUE)
  size <- file.info(rds_file)[["size"]]

  manifest <- data.frame(
    dataset = dataset,
    file = basename(rds_file),
    object = "Seurat",
    source = "TENxXeniumData::sfe_human_pancreas()",
    cells = ncol(xenium_human_pancreas_sub),
    features = nrow(xenium_human_pancreas_sub),
    assay = "Xenium",
    sha256 = sha,
    size_bytes = size,
    description = "Compact 10x Xenium human pancreas Seurat object for scop examples.",
    stringsAsFactors = FALSE
  )
  utils::write.table(
    manifest,
    file = file.path(output_dir, "manifest.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )

  message("Wrote: ", normalizePath(rds_file, mustWork = FALSE))
  message("Wrote: ", normalizePath(file.path(output_dir, "manifest.tsv"), mustWork = FALSE))
  invisible(xenium_human_pancreas_sub)
}
