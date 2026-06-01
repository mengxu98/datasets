#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
motif_dir="$(cd "${script_dir}/.." && pwd)"

mkdir -p \
  "${motif_dir}/JASPAR2024" \
  "${motif_dir}/HOCOMOCO_v14"

curl -L \
  "https://jaspar.elixir.no/download/data/2024/CORE/JASPAR2024_CORE_vertebrates_non-redundant_pfms_jaspar.txt" \
  -o "${motif_dir}/JASPAR2024/JASPAR2024_CORE_vertebrates_nonredundant_pfms_jaspar.txt"

curl -L \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/formatted_motifs/H14CORE_pfms.txt" \
  -o "${motif_dir}/HOCOMOCO_v14/H14CORE_pfms.txt"

curl -L \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/formatted_motifs/H14CORE_jaspar_format.txt" \
  -o "${motif_dir}/HOCOMOCO_v14/H14CORE_jaspar_format.txt"

curl -L \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/H14CORE_annotation.jsonl" \
  -o "${motif_dir}/HOCOMOCO_v14/H14CORE_annotation.jsonl"

curl -L \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/H14CORE-MOUSE_annotation.jsonl" \
  -o "${motif_dir}/HOCOMOCO_v14/H14CORE-MOUSE_annotation.jsonl"

shasum -a 256 \
  "${motif_dir}/JASPAR2024/"* \
  "${motif_dir}/HOCOMOCO_v14/"* \
  "${motif_dir}/motif2tf.rda" \
  "${motif_dir}/motif2tf.tsv" \
  "${motif_dir}/motifs.rda" \
  "${motif_dir}/summary.tsv" \
  > "${motif_dir}/SHA256SUMS.txt"
