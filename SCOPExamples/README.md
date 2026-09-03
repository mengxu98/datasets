# SCOP example assets

This directory contains compact, source-traceable objects used by `scop`
documentation and integration checks. The files are derived from public source
objects; they are not simulated data and they do not include native objects
from optional analysis backends.

## Objects

| Object | Class | Source and purpose |
|---|---|---|
| `visium_human_pancreas_results_sub` | `Seurat` | Real GSE254829 Visium counts and coordinates from the bundled SCOP object, with native `scop` spatial network/neighborhood bundles and validated plain-list results for the optional methods that completed in the pinned checkout. |
| `visium_human_pancreas_pair_sub` | `Seurat` | Real GSE254829 PanIN-LG1 (`GSM8058242`) and PanIN-LG2 (`GSM8058244`) tissue spots, retaining two explicitly labelled samples for multi-sample coordinate tests. |
| `xenium_human_pancreas_boundaries_sub` | `data.frame` | Real cell-segmentation polygon vertices extracted from `TENxXeniumData::spe_human_pancreas()`. The object is directly suitable for `SpatialCellPlot(boundaries = ...)`. |
| `pbmc_celltypist_sub` | `Seurat` or omitted | Real PBMC RNA counts from the bundled SCOP `pbmcmultiome_sub` object. A CellTypist result is stored only if the current `scop` wrapper and the `Immune_All_Low` model complete and pass alignment/schema/provenance checks. |

The `*_sub.rds` files are deliberately small. Visium source images are not
copied into the pair asset; raw acquisition coordinates are retained in `x`
and `y`, and `sample_id` identifies each section. The Xenium asset stores
ordinary columns (`cell_id`, `polygon_id`, `ring_id`, `vertex_order`, `x`,
`y`, `image`) rather than `sf` or Bioconductor geometry classes. The PBMC
asset never stores a Python `AnnData` or a CellTypist native object.

## Rebuild

Run from the repository root. Each script takes explicit source paths when
available and otherwise downloads the named public source. The result script
requires a local `scop` checkout because it executes the current wrappers.

```r
source("SCOPExamples/scripts/create_visium_human_pancreas_pair_sub.R")
create_visium_human_pancreas_pair_sub()

source("SCOPExamples/scripts/create_visium_human_pancreas_results_sub.R")
create_visium_human_pancreas_results_sub(scop_dir = "../scop")

source("SCOPExamples/scripts/create_xenium_human_pancreas_boundaries_sub.R")
create_xenium_human_pancreas_boundaries_sub()

source("SCOPExamples/scripts/create_pbmc_celltypist_sub.R")
create_pbmc_celltypist_sub(scop_dir = "../scop")

source("SCOPExamples/scripts/validate_assets.R")
validate_scop_example_assets()
```

The scripts are intentionally strict. A missing optional backend, a failed
wrapper call, an alignment mismatch, or a schema/provenance failure is written
as `omitted` in `manifest.tsv` and in the generated provenance report; no
fallback, random assignment, observed-count substitute, or synthetic backend
result is written.

The result asset records the method, backend, parameters, coordinate contract,
input cells/features, and SCOP provenance for each stored result. Optional
methods that do not pass the live wrapper and schema checks remain omitted;
the current manifest records those omissions explicitly.

## Provenance and licensing

- Visium: [GSE254829](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE254829), specifically `GSM8058242` / PanIN-LG1 and `GSM8058244` / PanIN-LG2 supplementary archives.
- Xenium: [TENxXeniumData](https://bioconductor.org/packages/TENxXeniumData/), resource `EH8549`, `spe_human_pancreas`, originally from the [10x Genomics human pancreas preview dataset](https://www.10xgenomics.com/resources/datasets/human-pancreas-preview-data-xenium-human-multi-tissue-and-cancer-panel-1-standard).
- PBMC: the SCOP repository's `data/pbmcmultiome_sub.rda`, whose source and
  preparation are documented by SCOP.
- CellTypist: the public `Immune_All_Low.pkl` model is used only for a live
  successful run; the model itself is not redistributed here.

Please follow the original data providers' terms. This repository stores
compact derived examples for reproducible academic communication and software
documentation.
