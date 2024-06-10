#!/usr/bin/env pwsh

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

$ErrorActionPreference = "Stop"

# Absolute path of this script
$SCRIPT_LOCATION = Split-Path $MyInvocation.MyCommand.Path -Parent

# Name of the docker image being built
$DOCKER_IMAGE_NAME = 'wasm-webserver-dev'

# Dockerfile target to use
$DOCKERFILE_TARGET = 'http_server_dev_env'

try {
    Push-Location $SCRIPT_LOCATION
    $PROJECT_ROOT = (git rev-parse --show-toplevel)
    Pop-Location

    Push-Location $PROJECT_ROOT

    # $START_LOCATION = $PWD.Path

    # build docker image
    # context is root of the git repo
    docker build --target $DOCKERFILE_TARGET -t $DOCKER_IMAGE_NAME -f ./dockerfiles/wasm.Dockerfile .

    # run docker image (dev mode : with dynamic volume content)
    docker run --rm -ti -p 1080:80 -p 1443:443 $DOCKER_IMAGE_NAME

    # -v ${PROJECT_ROOT}/wasm/wasm_server:/go/server \
}
catch {
    # an error occured

    Pop-Location
}
finally {
    # script ended successfully

    Pop-Location
}
