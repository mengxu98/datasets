#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
motif_dir="$(cd "${script_dir}/.." && pwd)"

check_one() {
  local label="$1"
  local url="$2"
  local path="$3"
  local local_size remote_size last_modified status

  if [[ ! -f "${path}" ]]; then
    printf "%s\tmissing_local\t%s\t%s\t%s\n" "${label}" "NA" "NA" "${path}"
    return 0
  fi

  local_size="$(wc -c < "${path}" | tr -d ' ')"
  remote_size="$(
    curl -L -sI "${url}" |
      awk 'BEGIN{IGNORECASE=1} /^Content-Length:/ {gsub("\r", "", $2); size=$2} END{print size}'
  )"
  last_modified="$(
    curl -L -sI "${url}" |
      awk 'BEGIN{IGNORECASE=1} /^Last-Modified:/ {sub(/^[^:]+: /, ""); gsub("\r", ""); lm=$0} END{print lm}'
  )"

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
