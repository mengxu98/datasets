#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
motif_dir="$(cd "${script_dir}/.." && pwd)"

mkdir -p \
  "${motif_dir}/JASPAR2024" \
  "${motif_dir}/HOCOMOCO_v14" \
  "${motif_dir}/FigR_cisBP" \
  "${motif_dir}/PlantTFDB" \
  "${motif_dir}/MEME_Suite"

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

curl -L \
  "https://zenodo.org/api/records/6814702/files/cisBP_human_pfms_2021.rds/content" \
  -o "${motif_dir}/FigR_cisBP/cisBP_human_pfms_2021.rds"

curl -L \
  "https://zenodo.org/api/records/6814702/files/cisBP_mouse_pfms_2021.rds/content" \
  -o "${motif_dir}/FigR_cisBP/cisBP_mouse_pfms_2021.rds"

curl -L -A "Mozilla/5.0" \
  "https://planttfdb.gao-lab.org/download/motif/PlantTFDB_TF_binding_motifs_from_experiments_information.txt" \
  -o "${motif_dir}/PlantTFDB/PlantTFDB_TF_binding_motifs_from_experiments_information.txt"

curl -L -A "Mozilla/5.0" \
  "https://planttfdb.gao-lab.org/download/motif/PlantTFDB_TF_binding_motifs_from_experiments.gz" \
  -o "${motif_dir}/PlantTFDB/PlantTFDB_TF_binding_motifs_from_experiments.meme.gz"

curl -L \
  "https://meme-suite.org/meme/meme-software/Databases/motifs/motif_databases.12.25.tgz" \
  -o "${motif_dir}/MEME_Suite/motif_databases.12.25.tgz"

tar -xOzf \
  "${motif_dir}/MEME_Suite/motif_databases.12.25.tgz" \
  motif_databases/motif_db.csv \
  > "${motif_dir}/MEME_Suite/motif_db.csv"

"${script_dir}/generate_checksums.sh"
