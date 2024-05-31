#!/bin/sh

set -e

START_LOCATION="$PWD"
SCRIPT_LOCATION=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# Go back to start location when script exits
trap "cd $START_LOCATION" EXIT

# Go to script location
cd "$SCRIPT_LOCATION"

# Use git command to get root project directory.
PROJECT_ROOT=$(git rev-parse --show-toplevel)

#
cd "$PROJECT_ROOT"/deps/libwebsockets/src

#
./fetch.sh

cd libwebsockets
rm -rf build

mkdir build
cd build

cmake .. \
-DCMAKE_OSX_DEPLOYMENT_TARGET="10.14" \
-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
-DLWS_OPENSSL_LIBRARIES="$PROJECT_ROOT"'/deps/libssl/macos/lib/libssl.a;'"$PROJECT_ROOT"'/deps/libssl/macos/lib/libcrypto.a' \
-DLWS_OPENSSL_INCLUDE_DIRS="$PROJECT_ROOT"'/deps/libssl/macos/include'

# -DCMAKE_BUILD_TYPE=DEBUG (flag to build with DEBUG)

# Build using the generated Makefiles
# ------------------------------------------------------

make -j8

# Copy build output into "output" directory
# ------------------------------------------------------

rm -rf "$PROJECT_ROOT"/deps/libwebsockets/macos/include
rm -rf "$PROJECT_ROOT"/deps/libwebsockets/macos/lib

cp -r ./include "$PROJECT_ROOT"/deps/libwebsockets/macos/

mkdir "$PROJECT_ROOT"/deps/libwebsockets/macos/lib

cp ./lib/libwebsockets.a "$PROJECT_ROOT"/deps/libwebsockets/macos/lib/libwebsockets.a