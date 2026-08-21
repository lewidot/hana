#!/usr/bin/env bash

set -euo pipefail

echo "Checking formatting..."
roc fmt --check package examples

echo "Checking Hana..."
roc check package/Hana.roc --main=package/main.roc

echo "Checking examples..."
roc check examples/hello.roc
roc check examples/sse.roc

echo "Generating docs..."
rm -rf generated-docs
./scripts/docs.sh

echo "Bundling Hana..."
rm -rf dist
./scripts/bundle.sh

echo "All checks passed."
