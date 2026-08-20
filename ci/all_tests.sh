#!/usr/bin/env bash

set -euo pipefail

roc fmt --check package examples
roc check package/Hana.roc --main=package/main.roc
roc check examples/hello.roc
