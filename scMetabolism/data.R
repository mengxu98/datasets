#' @title Metabolism pathway definitions parsed from scMetabolism
#'
#' @description
#' `metabolism_terms` stores KEGG and Reactome metabolism pathway
#' definitions parsed from the `scMetabolism` package. Each database contains
#' a `TERM2GENE` table, a `TERM2NAME` table, and a named `gene_sets` list.
#'
#' @md
#' @concept data
#' @format A list with `KEGG`, `Reactome`, and `metadata` entries.
#' @source
#' \href{https://github.com/wu-yc/scMetabolism}{scMetabolism}
#'
#' @examples
#' \dontrun{
#' check_r("YosefLab/VISION")
#' check_r("wu-yc/scMetabolism")
#'
#' parse_scmetabolism_gmt <- function(gmt_file, database) {
#'   if (!file.exists(gmt_file)) {
#'     stop("GMT file not found: ", gmt_file, call. = FALSE)
#'   }
#'
#'   lines <- readLines(gmt_file, warn = FALSE)
#'   split_lines <- strsplit(lines, "\t", fixed = TRUE)
#'
#'   pathway_name <- vapply(
#'     split_lines,
#'     function(x) x[[1]],
#'     FUN.VALUE = character(1)
#'   )
#'   pathway_ref <- vapply(
#'     split_lines,
#'     function(x) {
#'       if (length(x) >= 2) x[[2]] else NA_character_
#'     },
#'     FUN.VALUE = character(1)
#'   )
#'   genes_list <- lapply(
#'     split_lines,
#'     function(x) unique(stats::na.omit(x[-c(1, 2)]))
#'   )
#'
#'   term_id <- paste0(database, "::", pathway_name)
#'
#'   TERM2GENE <- do.call(
#'     rbind,
#'     lapply(seq_along(term_id), function(i) {
#'       data.frame(
#'         Term = term_id[[i]],
#'         symbol = genes_list[[i]],
#'         stringsAsFactors = FALSE
#'       )
#'     })
#'   )
#'   TERM2NAME <- data.frame(
#'     Term = term_id,
#'     Name = pathway_name,
#'     Database = database,
#'     Ref = pathway_ref,
#'     stringsAsFactors = FALSE
#'   )
#'
#'   list(
#'     TERM2GENE = TERM2GENE,
#'     TERM2NAME = TERM2NAME,
#'     gene_sets = stats::setNames(genes_list, pathway_name)
#'   )
#' }
#'
#' gmt_files <- c(
#'   KEGG = system.file(
#'     "data",
#'     "KEGG_metabolism_nc.gmt",
#'     package = "scMetabolism"
#'   ),
#'   Reactome = system.file(
#'     "data",
#'     "REACTOME_metabolism.gmt",
#'     package = "scMetabolism"
#'   )
#' )
#'
#' metabolism_terms <- lapply(
#'   names(gmt_files),
#'   function(db) parse_scmetabolism_gmt(gmt_files[[db]], db)
#' )
#' names(metabolism_terms) <- names(gmt_files)
#' metabolism_terms$metadata <- list(
#'   source = "wu-yc/scMetabolism",
#'   version = as.character(utils::packageVersion("scMetabolism")),
#'   created_at = as.character(Sys.time())
#' )
#' 
#' # usethis::use_data(
#' #   metabolism_terms,
#' #   compress = "xz",
#' #   overwrite = TRUE
#' # )
#' }
#' @name metabolism_terms
NULL
