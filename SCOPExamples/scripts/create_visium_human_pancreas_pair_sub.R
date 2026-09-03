# Build a compact, real two-sample Visium object from GSE254829.
#
# The source archives are the GEO supplementary files for GSM8058242
# (PanIN-LG1) and GSM8058244 (PanIN-LG2). The output contains no image raster;
# x/y are the raw full-resolution acquisition coordinates and sample_id is
# retained for explicit multi-sample analyses.

.scop_pair_urls <- c(
  GSM8058242 = paste0(
    "https://ftp.ncbi.nlm.nih.gov/geo/samples/GSM8058nnn/GSM8058242/suppl/",
    "GSM8058242_PanIN-LG1.tar.gz"
  ),
  GSM8058244 = paste0(
    "https://ftp.ncbi.nlm.nih.gov/geo/samples/GSM8058nnn/GSM8058244/suppl/",
    "GSM8058244_PanIN-LG2.tar.gz"
  )
)

create_visium_human_pancreas_pair_sub <- function(
  source_dirs = NULL,
  output_dir = file.path("SCOPExamples"),
  n_per_sample = 220L,
  n_features = 1500L,
  seed = 98L,
  dataset = "visium_human_pancreas_pair_sub",
  scop_dir = file.path("..", "scop"),
  run_integration = TRUE
) {
  required <- c("Seurat", "SeuratObject", "Matrix", "digest")
  if (isTRUE(run_integration)) required <- c(required, "pkgload")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (length(n_per_sample) != 1L || is.na(n_per_sample) || n_per_sample < 2L) {
    stop("n_per_sample must be one integer >= 2", call. = FALSE)
  }
  if (length(n_features) != 1L || is.na(n_features) || n_features < 10L) {
    stop("n_features must be one integer >= 10", call. = FALSE)
  }

  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  if (is.null(source_dirs)) {
    source_root <- file.path(tempdir(), "scop-gse254829")
    dir.create(source_root, recursive = TRUE, showWarnings = FALSE)
    source_dirs <- stats::setNames(vector("list", length(.scop_pair_urls)), names(.scop_pair_urls))
    for (sample_id in names(.scop_pair_urls)) {
      archive <- file.path(source_root, paste0(sample_id, ".tar.gz"))
      if (!file.exists(archive)) {
        utils::download.file(.scop_pair_urls[[sample_id]], archive, mode = "wb", quiet = FALSE)
      }
      extract_dir <- file.path(source_root, sample_id)
      dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
      utils::untar(archive, exdir = extract_dir)
      dirs <- list.dirs(extract_dir, full.names = TRUE, recursive = TRUE)
      source_dirs[[sample_id]] <- dirs[basename(dirs) %in% c("PanIN-LG1", "PanIN-LG2")][[1L]]
    }
  }
  if (!is.list(source_dirs)) {
    source_dirs <- as.list(source_dirs)
  }
  if (is.null(names(source_dirs)) || !all(names(.scop_pair_urls) %in% names(source_dirs))) {
    stop("source_dirs must be a named list containing GSM8058242 and GSM8058244", call. = FALSE)
  }

  read_sample <- function(sample_id, data_dir) {
    matrix_dir <- file.path(data_dir, "filtered_feature_bc_matrix")
    positions_file <- file.path(data_dir, "spatial", "tissue_positions_list.csv")
    if (!dir.exists(matrix_dir) || !file.exists(positions_file)) {
      stop("Missing 10x matrix or tissue positions for ", sample_id, call. = FALSE)
    }
    counts <- Seurat::Read10X(matrix_dir)
    if (is.list(counts)) {
      if (!"Gene Expression" %in% names(counts)) {
        stop("10x source for ", sample_id, " has no Gene Expression matrix", call. = FALSE)
      }
      counts <- counts[["Gene Expression"]]
    }
    counts <- methods::as(counts, "dgCMatrix")
    positions <- utils::read.csv(positions_file, header = FALSE, stringsAsFactors = FALSE)
    if (ncol(positions) < 6L) {
      stop("Tissue positions for ", sample_id, " must have six columns", call. = FALSE)
    }
    tissue <- positions[positions[[2L]] == 1, , drop = FALSE]
    cells <- intersect(colnames(counts), tissue[[1L]])
    if (length(cells) < 2L) {
      stop("No tissue spots overlap the matrix for ", sample_id, call. = FALSE)
    }
    counts <- counts[, cells, drop = FALSE]
    pos <- tissue[match(cells, tissue[[1L]]), , drop = FALSE]
    coords <- data.frame(
      x = as.numeric(pos[[6L]]),
      y = as.numeric(pos[[5L]]),
      row = as.integer(pos[[3L]]),
      col = as.integer(pos[[4L]]),
      row.names = cells,
      stringsAsFactors = FALSE
    )
    if (any(!is.finite(coords$x) | !is.finite(coords$y))) {
      stop("Non-finite tissue coordinates in ", sample_id, call. = FALSE)
    }
    set.seed(seed + match(sample_id, names(.scop_pair_urls)))
    center <- c(stats::median(coords$x), stats::median(coords$y))
    distance <- (coords$x - center[[1L]])^2 + (coords$y - center[[2L]])^2
    order_index <- order(distance, -Matrix::colSums(counts), rownames(coords))
    keep <- order_index[seq_len(min(as.integer(n_per_sample), length(order_index)))]
    cells_keep <- cells[keep]
    counts <- counts[, cells_keep, drop = FALSE]
    coords <- coords[cells_keep, , drop = FALSE]
    colnames(counts) <- paste0(sample_id, "_", colnames(counts))
    rownames(coords) <- colnames(counts)
    list(counts = counts, coords = coords, source_dir = normalizePath(data_dir, mustWork = FALSE))
  }

  samples <- lapply(names(.scop_pair_urls), function(sample_id) {
    read_sample(sample_id, source_dirs[[sample_id]])
  })
  names(samples) <- names(.scop_pair_urls)
  shared <- Reduce(intersect, lapply(samples, function(x) rownames(x$counts)))
  totals <- Reduce(`+`, lapply(samples, function(x) Matrix::rowSums(x$counts[shared, , drop = FALSE])))
  shared <- shared[order(totals, decreasing = TRUE, method = "radix")]
  genes <- shared[seq_len(min(as.integer(n_features), length(shared)))]
  counts <- do.call(cbind, lapply(samples, function(x) x$counts[genes, , drop = FALSE]))
  coords <- do.call(rbind, lapply(samples, function(x) x$coords[colnames(x$counts), , drop = FALSE]))
  sample_id <- sub("_.*$", "", colnames(counts))
  patient_sample <- c(GSM8058242 = "PanIN-LG1", GSM8058244 = "PanIN-LG2")[sample_id]
  metadata <- data.frame(
    sample_id = unname(sample_id),
    geo_accession = "GSE254829",
    patient_sample = unname(patient_sample),
    image = NA_character_,
    x = coords$x,
    y = coords$y,
    array_row = coords$row,
    array_col = coords$col,
    row.names = colnames(counts),
    stringsAsFactors = FALSE
  )
  pair <- Seurat::CreateSeuratObject(
    counts = counts,
    assay = "Spatial",
    project = "GSE254829_pair",
    meta.data = metadata,
    min.cells = 0,
    min.features = 0
  )
  pair <- Seurat::NormalizeData(pair, assay = "Spatial", verbose = FALSE)
  coda_file <- file.path(tempdir(), "GSE254829_codatable.csv.gz")
  if (!file.exists(coda_file)) {
    utils::download.file(
      "https://ftp.ncbi.nlm.nih.gov/geo/series/GSE254nnn/GSE254829/suppl/GSE254829_codatable_may202024.csv.gz",
      coda_file,
      mode = "wb",
      quiet = TRUE
    )
  }
  coda <- utils::read.csv(coda_file, check.names = FALSE)
  coda$barcode_clean <- sub("(_[0-9]+)+$", "", coda[[1L]])
  barcodes <- sub("^GSM805824[24]_", "", colnames(pair))
  sample_ids <- as.character(pair[["sample_id", drop = TRUE]])
  labels <- score <- rep(NA, ncol(pair))
  components <- c(
    "islets", "normal epithelium", "smooth muscle", "fat",
    "acini", "collagen", "panin"
  )
  for (sample_id in unique(sample_ids)) {
    idx <- which(sample_ids == sample_id)
    sample_name <- c(
      GSM8058242 = "PanIN-LG1",
      GSM8058244 = "PanIN-LG2"
    )[[sample_id]]
    rows <- which(coda$sample == sample_name)
    match_idx <- match(barcodes[idx], coda$barcode_clean[rows])
    keep <- !is.na(match_idx)
    if (any(keep)) {
      values <- coda[rows[match_idx[keep]], components, drop = FALSE]
      labels[idx[keep]] <- components[max.col(values, ties.method = "first")]
      score[idx[keep]] <- do.call(pmax, values)
    }
  }
  pair$sample <- pair$patient_sample
  pair$coda_label <- labels
  pair$coda_score <- score
  for (component in components) {
    values <- rep(NA_real_, ncol(pair))
    for (sample_id in unique(sample_ids)) {
      idx <- which(sample_ids == sample_id)
      sample_name <- c(
        GSM8058242 = "PanIN-LG1",
        GSM8058244 = "PanIN-LG2"
      )[[sample_id]]
      rows <- which(coda$sample == sample_name)
      match_idx <- match(barcodes[idx], coda$barcode_clean[rows])
      keep <- !is.na(match_idx)
      if (any(keep)) values[idx[keep]] <- coda[[component]][rows[match_idx[keep]]]
    }
    pair[[paste0("coda_", gsub(" ", ".", component))]] <- values
  }
  if (isTRUE(run_integration)) {
    scop_dir <- normalizePath(scop_dir, mustWork = TRUE)
    pkgload::load_all(scop_dir, quiet = TRUE, compile = FALSE)
    check_r("feiyoung/PRECAST", verbose = FALSE)
    pair <- RunSpatialIntegration(
      pair,
      method = "PRECAST",
      sample.by = "sample_id",
      assay = "Spatial",
      layer = "counts",
      coord.cols = c("x", "y"),
      features = rownames(pair)[seq_len(min(100L, nrow(pair)))],
      verbose = FALSE
    )
    pair$domain <- pair[["SpatialIntegration_PRECAST_domain", drop = TRUE]]
  }
  pair@tools[["SCOPExamples"]] <- list(
    asset = dataset,
    source = "GSE254829; GSM8058242/PanIN-LG1 + GSM8058244/PanIN-LG2",
    source_urls = unname(.scop_pair_urls),
    integration = if (isTRUE(run_integration)) {
      list(method = "PRECAST", status = "success", coordinate_space = "raw")
    } else {
      list(status = "not_run")
    },
    selection = list(
      strategy = "closest tissue spots to each sample median coordinate",
      requested_spots_per_sample = as.integer(n_per_sample),
      retained_spots = ncol(pair),
      retained_features = nrow(pair),
      seed = as.integer(seed)
    ),
    coordinate_contract = list(
      coordinate_space = "raw",
      coordinate_unit = "pixel",
      columns = c("x", "y"),
      image_policy = "no image raster stored; sample_id is explicit"
    )
  )
  rds_file <- file.path(output_dir, paste0(dataset, ".rds"))
  saveRDS(pair, rds_file, compress = "xz")
  message("Wrote ", normalizePath(rds_file, mustWork = FALSE))
  invisible(pair)
}
