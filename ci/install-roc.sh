#!/usr/bin/env bash

set -euo pipefail

platform="linux_x86_64"
install_dir="$PWD/.roc"

rm -rf "$install_dir"
mkdir -p "$install_dir"

if [[ -n "${ROC_NIGHTLY_TAG:-}" ]]; then
	release_url="https://api.github.com/repos/roc-lang/nightlies/releases/tags/${ROC_NIGHTLY_TAG}"
else
	release_url="https://api.github.com/repos/roc-lang/nightlies/releases/latest"
fi

download_url="$(
	curl -fsSL "$release_url" |
		jq -r \
			".assets[]
			| select(.name | contains(\"${platform}\"))
			| select(.name | endswith(\".tar.gz\"))
			| .browser_download_url"
)"

if [[ -z "$download_url" || "$download_url" == "null" ]]; then
	echo "Could not find Roc nightly for ${platform}" >&2
	exit 1
fi

curl -fsSL "$download_url" -o roc.tar.gz

tar \
	-xzf roc.tar.gz \
	-C "$install_dir" \
	--strip-components=1

rm roc.tar.gz

"$install_dir/roc" version
