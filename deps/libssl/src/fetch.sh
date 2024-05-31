#!/bin/sh

set -e

START_LOCATION="$PWD"
SCRIPT_LOCATION=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# Go back to start location when script exits
trap "cd $START_LOCATION" EXIT

# Go to script location
cd "$SCRIPT_LOCATION"

DIR=./openssl

if [ -d "$DIR" ]; then
    echo "src/openssl dir found, skip fetching"
    echo "(delete to fetch again)"
else 
    git clone --depth 1  --branch OpenSSL_1_1_1-stable https://github.com/openssl/openssl.git
fi