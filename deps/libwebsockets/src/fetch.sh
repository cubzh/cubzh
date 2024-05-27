#!/bin/sh

set -e

START_LOCATION="$PWD"
SCRIPT_LOCATION=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# Go back to start location when script exits
trap "cd $START_LOCATION" EXIT

# Go to script location
cd "$SCRIPT_LOCATION"

DIR=./libwebsockets

if [ -d "$DIR" ]; then
    echo "src/libwebsockets dir found, skip fetching"
    echo "(delete to fetch again)"
else 
    git clone --depth 1  --branch v4.3.2 https://github.com/warmcat/libwebsockets.git
fi
