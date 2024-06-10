#!/bin/bash

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

# build docker image
# context is root of the git repo
docker build --target web_server_empty -t wasm -f ./dockerfiles/wasm.Dockerfile .

# run docker image (dev mode : with dynamic volume content)
# note: using "$PWD" in docker commands does not work on Windows, use ${PROJECT_ROOT} instead
docker run --rm \
-v ${PROJECT_ROOT}/wasm/Particubes/build/output:/www \
-v /Users/gaetan/projects/voxowl/exe/certs/cu.bzh:/cubzh/certificates \
-e NO_CACHE=1 \
-p 1080:80 \
-p 1443:443 \
wasm