#!/bin/bash

set -ex

OUTPUT_DIR="lib/dts2hx-generated"

mkdir -p "$OUTPUT_DIR"

rm -rf "$OUTPUT_DIR"/*

npx dts2hx \
    @types/node \
    octokit \
    @octokit/auth-app \
    mysql2 \
    simple-git \
    @types/node-fetch \
    @types/fs-extra \
    --noLibWrap \
    --useSystemHaxe \
    --output \
    "$OUTPUT_DIR"
