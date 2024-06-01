#!/bin/bash

# 
# README
# 
# ⚠️
# 
# This is a development environment for the Go web server responsible 
# for serving the Cubzh Wasm "website". (.html, .js, .wasm, etc files)
# 
# This is ONLY for developer the web server itself, not the Cubzh wasm application!
# 

set -e

START_LOCATION="$PWD"
SCRIPT_LOCATION=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# Go back to start location when script exits
trap "cd $START_LOCATION" EXIT

# Go to script location before running git command
# to make sure it runs within project tree
cd "$SCRIPT_LOCATION"

# Use git command to get root project directory.
PROJECT_ROOT=$(git rev-parse --show-toplevel)

# The script is now executed from project root directory
cd "$PROJECT_ROOT"

DOCKER_IMAGE_NAME="wasm-webserver-dev"

# build docker image
# context is root of the git repo
docker build --target http_server_dev_env -t ${DOCKER_IMAGE_NAME} -f ./dockerfiles/wasm.Dockerfile .

# run docker image (dev mode : with dynamic volume content)
docker run --rm -ti \
-p 1080:80 \
-p 1443:443 \
-v $(pwd)/wasm/wasm_server:/go/server \
${DOCKER_IMAGE_NAME}
