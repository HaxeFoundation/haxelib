#!/bin/bash

set -ex

OUTPUT_DIR="lib/dts2hx-generated"

mkdir -p "$OUTPUT_DIR"

rm -rf "$OUTPUT_DIR"/*

npx dts2hx \
    octokit \
    @octokit/auth-app \
    mysql2 \
    --noLibWrap \
    --useSystemHaxe \
    --output \
    "$OUTPUT_DIR"

# https://github.com/haxiomic/dts2hx/issues/98
# find "$OUTPUT_DIR" -type f -exec sed -i 's/js.lib.AsyncIterator/js.lib.AsyncIterator_/g' {} +
# mv "$OUTPUT_DIR"/js/lib/AsyncIterator.hx "$OUTPUT_DIR"/js/lib/AsyncIterator_.hx
# sed -i 's/AsyncIterator/AsyncIterator_/g' "$OUTPUT_DIR"/js/lib/AsyncIterator_.hx
