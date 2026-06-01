#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
motif_dir="$(cd "${script_dir}/.." && pwd)"

check_one() {
  local label="$1"
  local url="$2"
  local path="$3"
  local local_size remote_size last_modified etag status

  if [[ ! -f "${path}" ]]; then
    printf "%s\tmissing_local\t%s\t%s\t%s\n" "${label}" "NA" "NA" "${path}"
    return 0
  fi

  local_size="$(wc -c < "${path}" | tr -d ' ')"
  remote_size="$(
    curl -L -A "Mozilla/5.0" -sI "${url}" |
      awk 'BEGIN{IGNORECASE=1} /^Content-Length:/ {gsub("\r", "", $2); size=$2} END{print size}'
  )"
  last_modified="$(
    curl -L -A "Mozilla/5.0" -sI "${url}" |
      awk 'BEGIN{IGNORECASE=1} /^Last-Modified:/ {sub(/^[^:]+: /, ""); gsub("\r", ""); lm=$0} END{print lm}'
  )"
  etag="$(
    curl -L -A "Mozilla/5.0" -sI "${url}" |
      awk 'BEGIN{IGNORECASE=1} /^ETag:/ {sub(/^[^:]+: /, ""); gsub("\r", ""); etag=$0} END{print etag}'
  )"

  if [[ -z "${remote_size}" && "${etag}" =~ ^W?/\"([0-9]+)- ]]; then
    remote_size="${BASH_REMATCH[1]}"
  fi

  if [[ "${local_size}" -le 5242880 ]]; then
    local body_size
    body_size="$(curl -L --fail -s "${url}" | wc -c | tr -d ' ' || true)"
    if [[ -n "${body_size}" && "${body_size}" -gt 0 ]]; then
      if [[ -z "${remote_size}" || "${remote_size}" -lt "${local_size}" ]]; then
        remote_size="${body_size}"
      fi
    fi
  fi

  if [[ -z "${remote_size}" ]]; then
    status="unknown_remote_size"
  elif [[ "${local_size}" == "${remote_size}" ]]; then
    status="ok"
  else
    status="changed_size"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${label}" "${status}" "${local_size}" "${remote_size:-NA}" "${last_modified:-NA}" "${path}"
}

printf "resource\tstatus\tlocal_size\tremote_size\tlast_modified\tpath\n"

check_one \
  "JASPAR2024_CORE_vertebrates_nonredundant" \
  "https://jaspar.elixir.no/download/data/2024/CORE/JASPAR2024_CORE_vertebrates_non-redundant_pfms_jaspar.txt" \
  "${motif_dir}/JASPAR2024/JASPAR2024_CORE_vertebrates_nonredundant_pfms_jaspar.txt"

check_one \
  "HOCOMOCO_v14_H14CORE_pfms" \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/formatted_motifs/H14CORE_pfms.txt" \
  "${motif_dir}/HOCOMOCO_v14/H14CORE_pfms.txt"

check_one \
  "HOCOMOCO_v14_H14CORE_jaspar_format" \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/formatted_motifs/H14CORE_jaspar_format.txt" \
  "${motif_dir}/HOCOMOCO_v14/H14CORE_jaspar_format.txt"

check_one \
  "HOCOMOCO_v14_H14CORE_annotation" \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/H14CORE_annotation.jsonl" \
  "${motif_dir}/HOCOMOCO_v14/H14CORE_annotation.jsonl"

check_one \
  "HOCOMOCO_v14_H14CORE_MOUSE_annotation" \
  "https://hocomoco14.autosome.org/final_bundle/hocomoco14/H14CORE/H14CORE-MOUSE_annotation.jsonl" \
  "${motif_dir}/HOCOMOCO_v14/H14CORE-MOUSE_annotation.jsonl"

check_one \
  "FigR_cisBP_human_pfms_2021" \
  "https://zenodo.org/api/records/6814702/files/cisBP_human_pfms_2021.rds/content" \
  "${motif_dir}/FigR_cisBP/cisBP_human_pfms_2021.rds"

check_one \
  "FigR_cisBP_mouse_pfms_2021" \
  "https://zenodo.org/api/records/6814702/files/cisBP_mouse_pfms_2021.rds/content" \
  "${motif_dir}/FigR_cisBP/cisBP_mouse_pfms_2021.rds"

check_one \
  "PlantTFDB_experimental_motif_information" \
  "https://planttfdb.gao-lab.org/download/motif/PlantTFDB_TF_binding_motifs_from_experiments_information.txt" \
  "${motif_dir}/PlantTFDB/PlantTFDB_TF_binding_motifs_from_experiments_information.txt"

check_one \
  "PlantTFDB_experimental_motifs_meme" \
  "https://planttfdb.gao-lab.org/download/motif/PlantTFDB_TF_binding_motifs_from_experiments.gz" \
  "${motif_dir}/PlantTFDB/PlantTFDB_TF_binding_motifs_from_experiments.meme.gz"

check_one \
  "MEME_Suite_motif_databases_12_25" \
  "https://meme-suite.org/meme/meme-software/Databases/motifs/motif_databases.12.25.tgz" \
  "${motif_dir}/MEME_Suite/motif_databases.12.25.tgz"
