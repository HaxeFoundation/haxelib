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
