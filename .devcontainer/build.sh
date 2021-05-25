#!/bin/bash

set -ex

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TAG="haxe/haxelib_devcontainer_workspace:$(date +%Y%m%d%H%M%S)"

cp -r "$DIR"/../*.hxml "$DIR"/../run.n "$DIR/workspace/"
docker build --pull -t "$TAG" "$DIR"

yq eval ".services.workspace.image = \"$TAG\"" "$DIR/docker-compose.yml" -i
