# Motif Resources

This directory stores transcription factor motif resources for
regulatory-network and chromatin-accessibility workflows.

## Contents

| Path | Resource | Species scope | Files |
| --- | --- | --- | --- |
| `JASPAR2024/` | JASPAR 2024 CORE vertebrates non-redundant PFMs | vertebrates | JASPAR flat PFM file |
| `HOCOMOCO_v14/` | HOCOMOCO v14 CORE motifs and annotations | human and mouse | PFM flat file, JASPAR-format file, all-motif and mouse-subset JSONL annotations |
| `FigR_cisBP/` | FigR-curated cisBP human and mouse PFMs | human and mouse | RDS PFM objects |
| `PlantTFDB/` | PlantTFDB experimentally derived TF binding motifs | plants | MEME gzip file and motif information table |
| `MEME_Suite/` | MEME Suite motif database bundle | broad multi-species | compressed database bundle and extracted database index |
| `motifs.rda`, `motif2tf.rda` | Human motif objects | mainly human | `TFBSTools::PFMatrixList`, motif-to-TF map, exported `motif2tf.tsv`, and `summary.tsv` |
| `external_resources.tsv` | Resources not mirrored in this repository | mixed | reason and recommended handling |

## Notes

- `motifs.rda` is a `TFBSTools::PFMatrixList`.
- `motif2tf.rda` maps motif IDs to TF symbols. The map contains CIS-BP,
  JASPAR2020, and sequence-similarity-derived mappings.
- HOCOMOCO v14 is included because the project site currently lists it as the
  latest HOCOMOCO release and provides CORE human/mouse annotations.
- FigR cisBP files provide compact human and mouse PFM RDS objects curated for
  single-cell multiome workflows.
- The MEME Suite bundle is stored as a compressed archive because it already
  contains many compatible MEME-format collections, including CIS-BP, UniPROBE,
  SwissRegulon, FlyFactorSurvey, YeTFaSCo, prokaryote, yeast, worm, plant, RNA
  and methylcytosine motif resources.
- CIS-BP and TRANSFAC-derived resources have licensing constraints. They should
  be integrated through user-provided local files or documented download steps
  unless redistribution terms are explicitly compatible with this repository.
- Some useful resources are documented but not mirrored here because they are
  very large, license-restricted, or do not expose a stable direct aggregate
  download. See `external_resources.tsv`.

## Rebuild

Run:

```bash
bash motifs/scripts/download_motifs.sh
Rscript motifs/scripts/summarize_motif_objects.R
```

Then regenerate checksums:

```bash
bash motifs/scripts/generate_checksums.sh
```

## Check for source updates

Run:

```bash
bash motifs/scripts/check_updates.sh
```

The script compares local file sizes with remote `Content-Length` headers for
downloaded JASPAR and HOCOMOCO source files and reports whether a remote file
appears changed.

## Sources

- JASPAR 2024: <https://jaspar.elixir.no/downloads/>
- HOCOMOCO v14: <https://hocomoco14.autosome.org/downloads>
- FigR cisBP RDS files: <https://zenodo.org/records/6814702>
- PlantTFDB motifs: <https://planttfdb.gao-lab.org/download.php>
- MEME Suite motif databases: <https://meme-suite.org/meme/db/motifs>
