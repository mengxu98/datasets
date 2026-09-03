# Build a compact real PBMC object and, when available, a live CellTypist
# result using the Immune_All_Low model. Never store a native Python object.

create_pbmc_celltypist_sub <- function(
  scop_dir = file.path("..", "scop"),
  source_rda = file.path(scop_dir, "data", "pbmcmultiome_sub.rda"),
  output_dir = file.path("SCOPExamples"),
  n_cells = 400L,
  dataset = "pbmc_celltypist_sub"
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
  pkgload::load_all(scop_dir, quiet = TRUE, compile = FALSE)
  source_env <- new.env(parent = emptyenv())
  source_names <- load(source_rda, envir = source_env)
  if (!"pbmcmultiome_sub" %in% source_names) {
    stop("Source RDA has no pbmcmultiome_sub object", call. = FALSE)
  }
  pbmc <- get("pbmcmultiome_sub", source_env)
  if (!inherits(pbmc, "Seurat")) stop("PBMC source must be Seurat", call. = FALSE)
  if (!"RNA" %in% SeuratObject::Assays(pbmc)) stop("PBMC source has no RNA assay", call. = FALSE)
  set.seed(98L)
  keep <- seq_len(min(as.integer(n_cells), ncol(pbmc)))
  pbmc <- pbmc[, keep]
  pbmc <- Seurat::DietSeurat(
    pbmc,
    assays = "RNA",
    dimreducs = NULL,
    graphs = NULL,
    misc = FALSE,
    counts = TRUE,
    data = TRUE,
    scale.data = FALSE
  )
  if (!"data" %in% SeuratObject::Layers(pbmc[["RNA"]])) {
    pbmc <- Seurat::NormalizeData(pbmc, assay = "RNA", verbose = FALSE)
  }

  omission <- NULL
  celltypist_success <- FALSE
  if (!exists("RunCellTypist", mode = "function")) {
    omission <- "Current SCOP checkout does not expose RunCellTypist()"
  } else {
    celltypist_try <- tryCatch(
      RunCellTypist(
        pbmc,
        assay = "RNA",
        layer = "data",
        model = "Immune_All_Low.pkl",
        insert_labels = TRUE,
        insert_conf = TRUE,
        insert_prob = FALSE,
        insert_decision = FALSE,
        return_seurat = TRUE,
        verbose = FALSE
      ),
      error = function(e) e
    )
    if (inherits(celltypist_try, "error")) {
      omission <- paste0("RunCellTypist failed: ", conditionMessage(celltypist_try))
    } else if (!inherits(celltypist_try, "Seurat")) {
      omission <- "RunCellTypist did not return a Seurat object"
    } else {
      labels <- grep("^celltypist_", colnames(celltypist_try[[]]), value = TRUE)
      if (length(labels) == 0L || !all(rownames(celltypist_try[[]]) == colnames(celltypist_try))) {
        omission <- "RunCellTypist returned no aligned prefixed labels"
      } else {
        pbmc <- celltypist_try
        celltypist_success <- TRUE
      }
    }
  }
  pbmc@tools[["SCOPExamples"]] <- list(
    asset = dataset,
    source = "SCOP data/pbmcmultiome_sub.rda",
    source_object = "pbmcmultiome_sub",
    selection = list(requested_cells = as.integer(n_cells), retained_cells = ncol(pbmc)),
    celltypist = list(
      status = if (celltypist_success) "success" else "omitted",
      model = "Immune_All_Low.pkl",
      wrapper = "RunCellTypist",
      native_payload = "not stored; Seurat metadata only",
      reason = omission
    )
  )
  rds_file <- file.path(output_dir, paste0(dataset, ".rds"))
  saveRDS(pbmc, rds_file, compress = "xz")
  message("Wrote ", normalizePath(rds_file, mustWork = FALSE))
  invisible(pbmc)
}
