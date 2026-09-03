# Extract real Xenium cellSeg polygons from TENxXeniumData::spe_human_pancreas.
#
# The committed object is an ordinary data.frame, not an sf/SFE object. This
# keeps the example independent of native Bioconductor geometry classes while
# retaining the source cell IDs, polygon/ring order, image name, and raw
# coordinates needed by scop::SpatialCellPlot().

create_xenium_human_pancreas_boundaries_sub <- function(
  source_rds = NULL,
  output_dir = file.path("SCOPExamples"),
  n_cells = 300L,
  dataset = "xenium_human_pancreas_boundaries_sub",
  seed = 98L
) {
  required <- c("TENxXeniumData", "SpatialExperiment", "SummarizedExperiment", "sf", "digest")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  source_label <- "TENxXeniumData::spe_human_pancreas()"
  source_path <- NULL
  source_object <- if (is.null(source_rds)) {
    TENxXeniumData::spe_human_pancreas()
  } else {
    source_path <- normalizePath(source_rds, mustWork = TRUE)
    readRDS(source_rds)
  }
  if (!inherits(source_object, "SpatialExperiment")) {
    stop("The Xenium source must inherit from SpatialExperiment", call. = FALSE)
  }
  counts <- SummarizedExperiment::assay(source_object, "counts")
  counts <- methods::as(counts, "dgCMatrix")
  cells <- colnames(counts)
  if (is.null(cells) || anyNA(cells) || anyDuplicated(cells)) {
    stop("Xenium source cell IDs must be unique and non-missing", call. = FALSE)
  }
  cell_seg <- SummarizedExperiment::colData(source_object)[["cellSeg"]]
  if (is.null(cell_seg)) {
    stop("TENxXeniumData::spe_human_pancreas has no cellSeg column", call. = FALSE)
  }
  cell_seg <- if (inherits(cell_seg, "sfc")) cell_seg else sf::st_as_sfc(cell_seg)
  centers <- SpatialExperiment::spatialCoords(source_object)
  if (ncol(centers) < 2L) stop("Xenium source has no two-dimensional centroids", call. = FALSE)
  centers <- as.data.frame(centers[, 1:2, drop = FALSE])
  colnames(centers) <- c("x", "y")
  rownames(centers) <- cells
  eligible <- which(!is.na(cell_seg) & is.finite(centers$x) & is.finite(centers$y) & Matrix::colSums(counts) > 0)
  if (length(eligible) < 1L) stop("No finite-count Xenium cells with cellSeg polygons", call. = FALSE)
  set.seed(seed)
  center <- c(stats::median(centers$x[eligible]), stats::median(centers$y[eligible]))
  distance <- (centers$x[eligible] - center[[1L]])^2 + (centers$y[eligible] - center[[2L]])^2
  selected <- eligible[order(distance, cells[eligible])]
  selected <- selected[seq_len(min(as.integer(n_cells), length(selected)))]
  selected_cells <- cells[selected]
  selected_seg <- cell_seg[selected]

  # st_coordinates() returns L1 = ring and L2 = polygon/cell for POLYGON
  # geometries; use L3 when a MULTIPOLYGON is present.
  vertices <- sf::st_coordinates(selected_seg)
  if (nrow(vertices) == 0L || !all(c("X", "Y") %in% colnames(vertices))) {
    stop("Xenium cellSeg contains no polygon vertices", call. = FALSE)
  }
  level_cell <- if ("L3" %in% colnames(vertices)) vertices[, "L3"] else vertices[, "L2"]
  level_polygon <- if ("L3" %in% colnames(vertices)) vertices[, "L2"] else rep(1, nrow(vertices))
  level_ring <- if ("L3" %in% colnames(vertices)) vertices[, "L1"] else vertices[, "L1"]
  cell_id <- selected_cells[as.integer(level_cell)]
  if (anyNA(cell_id)) stop("Could not align cellSeg vertices to source cell IDs", call. = FALSE)
  cell_area <- as.numeric(sf::st_area(selected_seg))[as.integer(level_cell)]
  boundaries <- data.frame(
    cell_id = as.character(cell_id),
    polygon_id = paste0("polygon_", as.integer(level_polygon)),
    ring_id = paste0("ring_", as.integer(level_ring)),
    vertex_order = ave(seq_len(nrow(vertices)), interaction(cell_id, level_polygon, level_ring, drop = TRUE), FUN = seq_along),
    x = as.numeric(vertices[, "X"]),
    y = as.numeric(vertices[, "Y"]),
    cell_area = cell_area,
    image = "xenium_pancreas",
    stringsAsFactors = FALSE
  )
  # Close every ring explicitly, as required by polygon plotting and the
  # validation script. The source polygon closure vertex is retained when it
  # is present; append it only when st_coordinates omitted the final repeat.
  groups <- interaction(boundaries$cell_id, boundaries$polygon_id, boundaries$ring_id, drop = TRUE, lex.order = TRUE)
  closed <- do.call(rbind, lapply(split(boundaries, groups), function(d) {
    d <- d[order(d$vertex_order), , drop = FALSE]
    if (!identical(c(d$x[[1L]], d$y[[1L]]), c(d$x[[nrow(d)]], d$y[[nrow(d)]]))) {
      d <- rbind(d, d[1L, , drop = FALSE])
      d$vertex_order <- seq_len(nrow(d))
    }
    d
  }))
  rownames(closed) <- NULL
  boundaries <- closed
  if (any(!is.finite(boundaries$x) | !is.finite(boundaries$y))) {
    stop("Xenium cellSeg vertices contain non-finite coordinates", call. = FALSE)
  }
  ring_key <- interaction(boundaries$cell_id, boundaries$polygon_id, boundaries$ring_id, drop = TRUE)
  if (any(vapply(split(seq_len(nrow(boundaries)), ring_key), function(i) {
    length(unique(boundaries$x[i] + boundaries$y[i] * 0i)) >= 3L
  }, logical(1)) == FALSE)) {
    stop("Xenium cellSeg ring has fewer than three distinct vertices", call. = FALSE)
  }
  attr(boundaries, "SCOPExamples") <- list(
    asset = dataset,
    source = source_label,
    source_path = source_path,
    experimenthub_id = "EH8549",
    source_object_class = class(source_object),
    source_package_version = as.character(utils::packageVersion("TENxXeniumData")),
    selection = list(
      strategy = "closest finite-count cells to median Xenium centroid",
      requested_cells = as.integer(n_cells),
      retained_cells = length(unique(boundaries$cell_id)),
      retained_vertices = nrow(boundaries),
      seed = as.integer(seed)
    ),
    coordinate_contract = list(
      coordinate_space = "raw",
      coordinate_unit = "micron (source Xenium coordinates)",
      columns = c("x", "y"),
      image = "xenium_pancreas"
    )
  )
  rds_file <- file.path(output_dir, paste0(dataset, ".rds"))
  saveRDS(boundaries, rds_file, compress = "xz")
  message("Wrote ", normalizePath(rds_file, mustWork = FALSE))
  invisible(boundaries)
}
