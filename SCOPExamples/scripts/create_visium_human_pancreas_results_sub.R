# Build a real native-scop result example from the bundled GSE254829 object.
#
# This script runs only package-native methods that are available in the
# current SCOP checkout. Optional backend results are not synthesized here.

create_visium_human_pancreas_results_sub <- function(
  scop_dir = file.path("..", "scop"),
  source_rda = file.path(scop_dir, "data", "visium_human_pancreas_sub.rda"),
  output_dir = file.path("SCOPExamples"),
  dataset = "visium_human_pancreas_results_sub",
  k = 4L,
  target_spots = 400L,
  grid_nx = 25L,
  grid_ny = 16L
) {
  required <- c("pkgload", "Seurat", "SeuratObject", "Matrix", "digest")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  scop_dir <- normalizePath(scop_dir, mustWork = TRUE)
  source_rda <- normalizePath(source_rda, mustWork = TRUE)
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  # Build from a temporary copy so compile=TRUE cannot modify the user's
  # checkout (pkgload may regenerate RcppExports files in the source tree).
  # This is still the exact supplied source checkout, not an installed or
  # alternative implementation.
  build_dir <- file.path(tempdir(), paste0("scop-example-build-", Sys.getpid()))
  dir.create(build_dir, recursive = TRUE, showWarnings = FALSE)
  source_files <- list.files(scop_dir, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  copied <- file.copy(source_files, build_dir, recursive = TRUE, copy.date = TRUE)
  if (!all(copied)) {
    stop("Could not copy the complete SCOP checkout to a temporary build directory", call. = FALSE)
  }
  pkgload::load_all(build_dir, quiet = TRUE, compile = TRUE)

  source_env <- new.env(parent = emptyenv())
  source_names <- load(source_rda, envir = source_env)
  if (!"visium_human_pancreas_sub" %in% source_names) {
    stop("Source RDA has no visium_human_pancreas_sub object", call. = FALSE)
  }
  spatial <- get("visium_human_pancreas_sub", source_env)
  if (!inherits(spatial, "Seurat")) {
    stop("The source object must be Seurat", call. = FALSE)
  }
  if (!all(c("x", "y", "sample_id") %in% colnames(spatial[[]]))) {
    stop("Source object lacks x, y, or sample_id metadata", call. = FALSE)
  }
  if (length(target_spots) != 1L || is.na(target_spots) || target_spots < 2L) {
    stop("target_spots must be one integer >= 2", call. = FALSE)
  }
  if (length(grid_nx) != 1L || is.na(grid_nx) || grid_nx < 1L ||
      length(grid_ny) != 1L || is.na(grid_ny) || grid_ny < 1L) {
    stop("grid_nx and grid_ny must be positive integers", call. = FALSE)
  }

  # Select one real spot nearest to each spatial grid-cell centre, then fill
  # any empty grid cells deterministically until the requested size is met.
  # This preserves tissue extent while keeping documentation assets small.
  md <- spatial[[]]
  finite <- is.finite(md$x) & is.finite(md$y)
  if (sum(finite) < target_spots) {
    stop("Source object has fewer finite-coordinate spots than target_spots", call. = FALSE)
  }
  x_range <- range(md$x[finite])
  y_range <- range(md$y[finite])
  x_width <- max(diff(x_range), 1)
  y_width <- max(diff(y_range), 1)
  gx <- pmin(grid_nx - 1L, floor((md$x - x_range[[1L]]) / x_width * grid_nx))
  gy <- pmin(grid_ny - 1L, floor((md$y - y_range[[1L]]) / y_width * grid_ny))
  grid_id <- gx + grid_nx * gy
  grid_id[!finite] <- NA_integer_
  grid_center_distance <- (
    md$x - (x_range[[1L]] + (gx + 0.5) * x_width / grid_nx)
  )^2 + (
    md$y - (y_range[[1L]] + (gy + 0.5) * y_width / grid_ny)
  )^2
  candidate_groups <- split(which(finite), grid_id[finite], drop = TRUE)
  selected <- vapply(candidate_groups, function(ii) {
    ii[order(grid_center_distance[ii], rownames(md)[ii])[[1L]]]
  }, integer(1))
  selected <- unname(selected)
  if (length(selected) < target_spots) {
    remaining <- setdiff(which(finite), selected)
    remaining <- remaining[order(grid_id[remaining], grid_center_distance[remaining], rownames(md)[remaining])]
    selected <- c(selected, remaining[seq_len(min(target_spots - length(selected), length(remaining)))])
  }
  selected <- selected[seq_len(min(target_spots, length(selected)))]
  spatial <- spatial[, rownames(md)[selected]]
  # Keep raw coordinates but omit the Visium image raster and image S4 object.
  spatial@images <- list()
  if (!"data" %in% SeuratObject::Layers(spatial[["Spatial"]])) {
    spatial <- Seurat::NormalizeData(spatial, assay = "Spatial", verbose = FALSE)
  }

  # These are package-native producers. They do not dispatch to an optional
  # backend and their stored payloads are ordinary data frames/lists.
  spatial <- RunSpatialNetwork(
    spatial,
    method = "knn",
    k = as.integer(k),
    coord.cols = c("x", "y"),
    verbose = FALSE
  )
  spatial <- RunSpatialNeighborhood(
    spatial,
    group.by = "coda_label",
    coord.cols = c("x", "y"),
    k = as.integer(k),
    verbose = FALSE
  )
  spatial <- RunSpatialGradientFeatures(
    spatial,
    reference = "trajectory",
    backend = "cpp",
    result_name = "scop_gradient_fixture",
    variables = rownames(spatial)[seq_len(min(4L, nrow(spatial)))],
    start = c(min(spatial$x), min(spatial$y)),
    end = c(max(spatial$x), max(spatial$y)),
    assay = "Spatial",
    layer = "counts",
    coord.cols = c("x", "y"),
    n_random = 0,
    n_bins = 5,
    min_spots = 3,
    sign_threshold = 1,
    nfeatures = 4,
    verbose = FALSE
  )

  network <- spatial@tools[["SpatialNetwork"]]
  neighborhood <- spatial@tools[["SpatialNeighborhood"]]
  if (!is.list(network) || is.null(network$graphs) || is.null(network$active_graph)) {
    stop("Native SpatialNetwork result is incomplete", call. = FALSE)
  }
  if (!is.list(neighborhood) || is.null(neighborhood$methods) ||
      is.null(neighborhood$active_method)) {
    stop("Native SpatialNeighborhood result is incomplete", call. = FALSE)
  }
  graph <- network$graphs[[network$active_graph]]
  nb <- neighborhood$methods[[neighborhood$active_method]]
  if (!is.data.frame(graph$nodes) || !is.data.frame(graph$edges) ||
      !all(c("cell_id", "x", "y") %in% colnames(graph$nodes)) ||
      !all(c("from", "to", "distance", "weight") %in% colnames(graph$edges))) {
    stop("Native SpatialNetwork schema validation failed", call. = FALSE)
  }
  if (!is.data.frame(nb$pair_table) || nrow(nb$pair_table) == 0L ||
      !all(c("from", "to", "count") %in% colnames(nb$pair_table))) {
    stop("Native SpatialNeighborhood schema validation failed", call. = FALSE)
  }
  if (any(!is.finite(graph$nodes$x) | !is.finite(graph$nodes$y))) {
    stop("Native SpatialNetwork has non-finite coordinates", call. = FALSE)
  }
  if (!identical(as.character(graph$nodes$cell_id), colnames(spatial))) {
    stop("Native SpatialNetwork node order does not match Seurat cells", call. = FALSE)
  }
  for (field in c("source", "parameters")) {
    if (is.null(graph[[field]])) stop("Native SpatialNetwork lacks ", field, call. = FALSE)
  }

  spatial@tools[["SCOPExamples"]] <- list(
    asset = dataset,
    source = "SCOP data/visium_human_pancreas_sub.rda derived from GSE254829 GSM8058244",
    producers = c(
      "RunSpatialNetwork(method = 'knn')",
      "RunSpatialNeighborhood(method = 'observed')",
      "RunSpatialGradientFeatures(backend = 'cpp', n_random = 0)"
    ),
    selection = list(
      strategy = paste0("one nearest real spot per ", grid_nx, " x ", grid_ny, " spatial grid cell, then deterministic fill"),
      target_spots = as.integer(target_spots),
      retained_spots = ncol(spatial),
      image_raster = "omitted; raw x/y metadata retained"
    ),
    validation = list(
      network_nodes = nrow(graph$nodes),
      network_edges = nrow(graph$edges),
      neighborhood_pairs = nrow(nb$pair_table),
      grid_nx = as.integer(grid_nx),
      grid_ny = as.integer(grid_ny),
      grid_target_spots = as.integer(target_spots),
      node_ids_match_cells = TRUE,
      finite_coordinates = TRUE,
      result_payloads = "ordinary data.frame/list; no optional backend native object"
    ),
    omitted = data.frame(
      method = c("SpatialCellChat", "LIANA", "SpotSweeper"),
      status = rep("omitted", 3L),
      reason = c(
        "No optional SpatialCellChat result was run for this compact asset",
        "No optional LIANA result was run for this compact asset",
        "SpotSweeper is intentionally not generated as a stored example result"
      ),
      stringsAsFactors = FALSE
    )
  )

  rds_file <- file.path(output_dir, paste0(dataset, ".rds"))
  saveRDS(spatial, rds_file, compress = "xz")
  message("Wrote ", normalizePath(rds_file, mustWork = FALSE))
  invisible(spatial)
}
