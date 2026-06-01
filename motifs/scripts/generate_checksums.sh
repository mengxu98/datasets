#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
motif_dir="$(cd "${script_dir}/.." && pwd)"

find "${motif_dir}" \
  -type f \
  ! -path "${motif_dir}/SHA256SUMS.txt" \
  ! -path "${motif_dir}/scripts/*" \
  -print0 |
  sort -z |
  xargs -0 shasum -a 256 |
  sed "s#  ${motif_dir}/#  motifs/#" \
  > "${motif_dir}/SHA256SUMS.txt"
