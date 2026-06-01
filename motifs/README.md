# Motif Resources

This directory stores transcription factor motif resources for
regulatory-network and chromatin-accessibility workflows.

## Contents

| Path | Resource | Species scope | Files |
| --- | --- | --- | --- |
| `JASPAR2024/` | JASPAR 2024 CORE vertebrates non-redundant PFMs | vertebrates | JASPAR flat PFM file |
| `HOCOMOCO_v14/` | HOCOMOCO v14 CORE motifs and annotations | human and mouse | PFM flat file, JASPAR-format file, all-motif and mouse-subset JSONL annotations |
| `motifs.rda`, `motif2tf.rda` | Human motif objects | mainly human | `TFBSTools::PFMatrixList`, motif-to-TF map, exported `motif2tf.tsv`, and `summary.tsv` |

## Notes

- `motifs.rda` is a `TFBSTools::PFMatrixList`.
- `motif2tf.rda` maps motif IDs to TF symbols. The map contains CIS-BP,
  JASPAR2020, and sequence-similarity-derived mappings.
- HOCOMOCO v14 is included because the project site currently lists it as the
  latest HOCOMOCO release and provides CORE human/mouse annotations.
- CIS-BP and TRANSFAC-derived resources have licensing constraints. They should
  be integrated through user-provided local files or documented download steps
  unless redistribution terms are explicitly compatible with this repository.

## Rebuild

Run:

```bash
bash motifs/scripts/download_motifs.sh
Rscript motifs/scripts/summarize_motif_objects.R
```

Then regenerate checksums:

```bash
shasum -a 256 motifs/JASPAR2024/* motifs/HOCOMOCO_v14/* motifs/motif2tf.rda motifs/motif2tf.tsv motifs/motifs.rda motifs/summary.tsv > motifs/SHA256SUMS.txt
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
