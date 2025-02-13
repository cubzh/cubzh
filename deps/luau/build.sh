#!/bin/bash

# exit on error
set -e

# exit on undefined variable
set -u

# exit on pipe error
set -o pipefail

# print commands
# set -x

# Store path of executable parent directory
SCRIPT_PARENT_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse flags and store them in variables
platform=""
version=""
while getopts ":p:v:" opt; do
  case ${opt} in
    p ) platform=$OPTARG ;;
    v ) version=$OPTARG ;;
    \? ) echo "Usage: $0 [-p platform] [-v version (optional)]" ;;
  esac
done

# Validate required parameters
if [ -z "$platform" ]; then
  echo "⚠️ Platform is not specified"
  echo "Usage: $0 [-p platform] [-v version (optional)]"
  exit 1
fi

# If version is "", get the latest version from the GitHub API
if [ -z "$version" ]; then
  echo -n "🔍 No version provided. Getting latest version from GitHub API..."
  version=$(curl -s https://api.github.com/repos/luau-lang/luau/releases/latest | jq -r '.tag_name')
  echo " ✅ [$version]"
fi

# if version is empty, exit
if [ -z "$version" ]; then
  echo "⚠️ Version is empty"
  exit 1
fi

# Make sure the Luau source code is present

DEPENDENCY_VERSION_PATH="${SCRIPT_PARENT_DIR_PATH}/${version}"
SOURCE_CODE_PATH="${DEPENDENCY_VERSION_PATH}/src"

# check presence of ./src directory
if [ ! -d ${SOURCE_CODE_PATH} ]; then
  echo "🔍 Luau source code looks to be missing. Downloading it..."
  ${SCRIPT_PARENT_DIR_PATH}/download.sh -q -v ${version} -o ${DEPENDENCY_VERSION_PATH}
fi

# check presence of *.cpp files in src directory or its subdirectories
if [ -z "$(find ${SOURCE_CODE_PATH} -name '*.cpp')" ]; then
  echo "🔍 Luau source code looks to be missing. Downloading it..."
  ${SCRIPT_PARENT_DIR_PATH}/download.sh -q -v ${version} -o ${DEPENDENCY_VERSION_PATH}
fi

# --- Copy the source code to the current directory for bazel to find it ---

cp -r ${SOURCE_CODE_PATH} ${SCRIPT_PARENT_DIR_PATH}/src

# --- Build ---

if [ "$platform" == "android" ]; then

  # make sure env var ANDROID_NDK_HOME is set
  if [ -z "${ANDROID_NDK_HOME}" ]; then
    echo "🔍 ANDROID_NDK_HOME is not set"
    exit 1
  fi

  platform_to_build="android"
  archs_to_build=("armv7" "arm64" "x86_32" "x86_64")

elif [ "$platform" == "ios" ]; then
  platform_to_build="ios"
  archs_to_build=("arm64")
  # TODO: might want to use apple_static_library() to create a Universal Binary library
  #       https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-apple.md#apple_static_library

elif [ "$platform" == "macos" ]; then
  platform_to_build="macos"
  archs_to_build=("universal") # TODO: remove when porting this to Golang

elif [ "$platform" == "windows" ]; then
  platform_to_build="windows"
  archs_to_build=("x86_64")

# elif [ "$platform" == "linux" ]; then
  # platform_to_build="linux"
  # archs_to_build=("x86_64")

# elif [ "$platform" == "wasm" ]; then
  # platform_to_build="wasm"
  # archs_to_build=("wasm")

else
  echo "⚠️ Unsupported platform name: $platform"
  exit 1
fi

# Define the artifact name based on the platform
artifact_name="libluau.a"
artifact_destination_name=$artifact_name
bazel_command_suffix=""

if [ "$platform" == "windows" ]; then
  artifact_name="luau-default.lib"
  artifact_destination_name="luau.lib"

elif [ "$platform" == "macos" ]; then
  artifact_name="luau-macos_lipo.a"
  bazel_command_suffix="--macos_cpus=arm64,x86_64"

elif [ "$platform" == "android" ]; then
  artifact_name="libluau-default.a"

elif [ "$platform" == "ios" ]; then
  artifact_name="libluau-default.a"
fi

echo "🛠️ Building Luau for $platform_to_build... (${archs_to_build[@]})"

# build for each architecture
for arch in "${archs_to_build[@]}"; do
  
  # recreate output directory
  output_dir="$version/prebuilt/$platform_to_build/$arch"
  rm -rf $output_dir && mkdir -p $output_dir
  
  # build
  bazel build //deps/luau:luau --platforms=//:${platform_to_build}_${arch} $bazel_command_suffix
  
  # move the library to the output directory
  mkdir -p $output_dir/lib
  mv ../../bazel-bin/deps/luau/$artifact_name $output_dir/lib/$artifact_destination_name

  # move the header files to the output directory
  mkdir -p $output_dir/include
  # copy and merge all include directories from src tree to output directory
  for dir in ${SCRIPT_PARENT_DIR_PATH}/src/*/include/; do
    if [ -d "$dir" ]; then
      cp -r "$dir"* "$output_dir/include/"
    fi
  done

done

# --- Clean up ---

rm -rf ${SCRIPT_PARENT_DIR_PATH}/src

# --- The End ---

echo "✅ Done. $platform_to_build | ${archs_to_build[@]}"
