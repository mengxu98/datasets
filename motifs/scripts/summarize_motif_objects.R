#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[grep(file_arg, args)])
script_dir <- dirname(normalizePath(script_path))
motif_dir <- normalizePath(file.path(script_dir, ".."))

load(file.path(motif_dir, "motifs.rda"))
load(file.path(motif_dir, "motif2tf.rda"))

write.table(
  motif2tf,
  file = file.path(motif_dir, "motif2tf.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

summary_df <- data.frame(
  resource = c("motifs_rda", "motif2tf_rda"),
  source = c("mixed", "mixed"),
  n_motifs = c(length(motifs@listData), length(unique(motif2tf$motif))),
  n_tfs = c(NA_integer_, length(unique(motif2tf$tf))),
  n_links = c(NA_integer_, nrow(motif2tf)),
  notes = c(
    "TFBSTools PFMatrixList human motif resource",
    paste(names(table(motif2tf$origin)), table(motif2tf$origin), sep = "=", collapse = "; ")
  )
)

write.table(
  summary_df,
  file = file.path(motif_dir, "summary.tsv"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)
