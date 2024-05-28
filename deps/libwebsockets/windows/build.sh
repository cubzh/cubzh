#!/bin/bash

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

# # Generate Makefiles
# # ------------------------------------------------------

cmake -G "Visual Studio 16" .. \
-DLWS_OPENSSL_LIBRARIES="$PROJECT_ROOT"'\deps\libssl\windows\lib\x64\release\libssl.lib;'"$PROJECT_ROOT"'\deps\libssl\windows\lib\x64\release\libcrypto.lib' \
-DLWS_OPENSSL_INCLUDE_DIRS="$PROJECT_ROOT"'\deps\libssl\windows\include'

# # -DLWS_HAVE_PTHREAD_H=1 \
# # -DLWS_EXT_PTHREAD_INCLUDE_DIR="$PROJECT_ROOT"'/deps/pthreads/windows/include' \
# # -DLWS_EXT_PTHREAD_LIBRARIES="$PROJECT_ROOT"'/deps/pthreads/windows/lib/x64/libpthreadGC2.a'

# # Build using the generated Makefiles
# # ------------------------------------------------------

cmake --build . #-j 4

# Copy build output into "output" directory
# ------------------------------------------------------

# rm -rf ./../../libwebsockets/windows/include
rm -rf "$PROJECT_ROOT"/deps/libwebsockets/windows/include
# rm -rf ./../../libwebsockets/windows/lib
rm -rf "$PROJECT_ROOT"/deps/libwebsockets/windows/lib

# copy headers
cp -r ./include "$PROJECT_ROOT"/deps/libwebsockets/windows/include

# copy libs
mkdir "$PROJECT_ROOT"/deps/libwebsockets/windows/lib
# debug
cp ./lib/Debug/websockets_static.lib "$PROJECT_ROOT"/deps/libwebsockets/windows/lib/websockets_static_debug.lib
cp ./lib/Debug/websockets_static.pdb "$PROJECT_ROOT"/deps/libwebsockets/windows/lib/websockets_static.pdb
# release
# TODO
