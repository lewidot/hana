#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$root_dir/generated-docs}"

mkdir -p "$output_dir"

roc docs \
  --output="$output_dir" \
  "$root_dir/package/main.roc"

echo "Generated Hana documentation in $output_dir"
