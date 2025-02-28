# Luau

## Build commands

To be run from cubzh/cubzh repo root dir

**Bash**

```sh
# android
./build.sh -p android
# bazel build //deps/libluau:luau --platforms=//:android_arm64
# bazel build //deps/libluau:luau --platforms=//:android_arm
# bazel build //deps/libluau:luau --platforms=//:android_x86
# bazel build //deps/libluau:luau --platforms=//:android_x86_64

# ios
./build.sh -p ios
# bazel build //deps/libluau:luau --platforms=//:ios_arm64

# macos
./build.sh -p macos
# bazel build //deps/libluau:luau --platforms=//:macos_universal --macos_cpus=arm64,x86_64

# windows
./build.sh -p windows
# bazel build //deps/libluau:luau --platforms=//:windows_x86
# bazel build //deps/libluau:luau --platforms=//:windows_x86_64

# linux
# From cubzh/cubzh repo root dir
docker run --rm -v $(pwd):/cubzh -w /cubzh/deps/libluau --entrypoint /bin/bash --platform linux/amd64 voxowl/bazel:8.1.1 ./build.sh -p linux -v 0.661
# With source override
docker run --rm -v $(pwd):/cubzh -v /Users/gaetan/projects/gdevillele/luau:/src -w /cubzh/deps/libluau --entrypoint /bin/bash --platform linux/amd64 voxowl/bazel:8.1.1 ./build.sh -p linux -v head -s /src
# bazel build //deps/libluau:luau --platforms=//:linux_x86_64

# wasm
# ./build.sh -p wasm
# bazel build //deps/libluau:luau --platforms=//:wasm_wasm32
# bazel build //deps/libluau:luau --platforms=//:wasm_wasm64
```
