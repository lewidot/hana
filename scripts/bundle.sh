#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$root_dir/dist}"

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"

cd "$root_dir/package"

roc_files=(main.roc)

for file in *.roc; do
	if [[ "$file" != "main.roc" ]]; then
		roc_files+=("$file")
	fi
done

roc bundle "${roc_files[@]}" --output-dir "$output_dir"
