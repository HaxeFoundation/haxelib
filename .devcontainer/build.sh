#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
IMAGE="haxe/haxelib_devcontainer_workspace"
TAG="${IMAGE}:$(date +%Y%m%d%H%M%S)"

mkdir -p "$DIR/workspace/"
cp -r "$DIR"/../*.hxml "$DIR"/../run.n "$DIR"/../package.json "$DIR"/../yarn.lock "$DIR"/../generate_extern.sh "$DIR"/../lib "$DIR/workspace/"
docker build --pull -t "$TAG" "$DIR"

sed -i -e "s#${IMAGE}:[0-9]*#$TAG#g" \
    "$DIR/docker-compose.yml" \
    "$DIR/../.github/workflows/ci-dev.yml" \
    "$DIR/../.github/workflows/ci-prod.yml"
