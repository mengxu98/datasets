#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required.")
  }
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("Package 'reticulate' is required.")
  }
})

record_id <- "18763485"
record_url <- paste0("https://zenodo.org/api/records/", record_id)
`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

file_arg <- commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))]
script_path <- if (length(file_arg) > 0L) {
  normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE)
} else {
  normalizePath("tAge/scripts/download_and_convert_en_models.R", mustWork = FALSE)
}
script_dir <- dirname(script_path)
root_dir <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)
model_dir <- file.path(root_dir, "EN", "models")
manifest_path <- file.path(root_dir, "EN", "manifest.tsv")
tmp_dir <- file.path(tempdir(), paste0("tage-en-pkl-", Sys.getpid()))
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

download_json <- function(url) {
  jsonlite::fromJSON(url, simplifyVector = FALSE)
}

parse_en_key <- function(key) {
  stem <- sub("\\.pkl$", "", key)
  parts <- strsplit(stem, "_", fixed = TRUE)[[1]]
  if (length(parts) < 5L || !identical(parts[[1]], "EN")) {
    stop("Unexpected EN model filename: ", key)
  }
  preprocessing_token <- parts[[length(parts)]]
  preprocessing <- switch(preprocessing_token,
    scaleddiff = "scaled_diff",
    yugenediff = "yugene_diff",
    preprocessing_token
  )
  list(
    mode = parts[[1]],
    clock = parts[[2]],
    model_species = parts[[3]],
    tissue = paste(parts[4:(length(parts) - 1L)], collapse = "_"),
    preprocessing = preprocessing
  )
}

patch_simple_imputer <- function(imputer) {
  reticulate::py_run_string(
    "
def patch_simple_imputer(imputer):
    if not hasattr(imputer, '_fill_dtype'):
        if hasattr(imputer, 'statistics_'):
            imputer._fill_dtype = imputer.statistics_.dtype
        else:
            import numpy as np
            imputer._fill_dtype = np.float64
def pipeline_info(model):
    return [
        {
            'name': name,
            'class': step.__class__.__module__ + '.' + step.__class__.__name__
        }
        for name, step in model.steps
    ]
"
  )
  reticulate::py$patch_simple_imputer(imputer)
}

convert_model <- function(pkl_path, file_info, record) {
  joblib <- reticulate::import("joblib", convert = FALSE)
  sklearn <- reticulate::import("sklearn", convert = TRUE)
  model <- joblib$load(pkl_path)
  steps <- model$named_steps
  patch_simple_imputer(steps[["imputation"]])

  parsed <- parse_en_key(file_info$key)
  selector <- steps[["featureselection"]]
  k <- reticulate::py_to_r(selector$k)
  selected <- if (identical(k, "all")) {
    rep(TRUE, length(reticulate::py_to_r(model$feature_names_in_)))
  } else {
    as.logical(reticulate::py_to_r(selector$get_support()))
  }

  list(
    model_type = "ElasticNet",
    format_version = 1L,
    pipeline = reticulate::py_to_r(reticulate::py$pipeline_info(model)),
    sklearn_version = sklearn$`__version__`,
    mode = parsed$mode,
    clock = parsed$clock,
    model_species = parsed$model_species,
    tissue = parsed$tissue,
    preprocessing = parsed$preprocessing,
    feature_names = as.character(reticulate::py_to_r(model$feature_names_in_)),
    imputer_statistics = as.numeric(reticulate::py_to_r(steps[["imputation"]]$statistics_)),
    center = as.numeric(reticulate::py_to_r(steps[["scaler"]]$mean_)),
    scale = {
      scale <- reticulate::py_to_r(steps[["scaler"]]$scale_)
      if (is.null(scale)) NULL else as.numeric(scale)
    },
    selected = selected,
    coef = as.numeric(reticulate::py_to_r(steps[["estimator"]]$coef_)),
    intercept = as.numeric(reticulate::py_to_r(steps[["estimator"]]$intercept_)),
    species_adjustment = c(human = 122.5, mouse = 48, rat = 50.4, monkey = 39),
    source = list(
      zenodo_record = record_id,
      zenodo_doi = record$doi,
      zenodo_url = record$links$self_html,
      file = file_info$key,
      file_url = file_info$links$self,
      checksum = file_info$checksum,
      size = file_info$size,
      publication_doi = "10.1038/s41586-026-10542-3",
      code_repository = "https://github.com/Gladyshev-Lab/tAge"
    )
  )
}

record <- download_json(record_url)
files <- record$files
en_files <- files[vapply(files, function(x) grepl("^EN_.*\\.pkl$", x$key), logical(1))]
en_files <- en_files[order(vapply(en_files, function(x) x$key, character(1)))]

manifest <- vector("list", length(en_files))
for (i in seq_along(en_files)) {
  info <- en_files[[i]]
  parsed <- parse_en_key(info$key)
  pkl_path <- file.path(tmp_dir, info$key)
  rds_file <- sub("\\.pkl$", ".rds", info$key)
  rds_path <- file.path(model_dir, rds_file)

  message("[", i, "/", length(en_files), "] ", info$key)
  if (!file.exists(pkl_path) || file.info(pkl_path)$size != info$size) {
    utils::download.file(info$links$self, pkl_path, mode = "wb", quiet = FALSE)
  }
  if (!identical(unname(tools::md5sum(pkl_path)), sub("^md5:", "", info$checksum))) {
    stop("MD5 mismatch for ", info$key)
  }

  model <- convert_model(pkl_path, info, record)
  saveRDS(model, rds_path, compress = "xz")
  rds_md5 <- unname(tools::md5sum(rds_path))
  manifest[[i]] <- data.frame(
    file = info$key,
    rds_file = file.path("models", rds_file),
    mode = parsed$mode,
    clock = parsed$clock,
    model_species = parsed$model_species,
    tissue = parsed$tissue,
    preprocessing = parsed$preprocessing,
    source_size = info$size,
    source_checksum = info$checksum,
    source_url = info$links$self,
    rds_size = file.info(rds_path)$size,
    rds_md5 = rds_md5,
    stringsAsFactors = FALSE
  )
}

manifest_df <- do.call(rbind, manifest)
utils::write.table(
  manifest_df,
  manifest_path,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)
message("Wrote ", manifest_path)
