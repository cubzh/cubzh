# Luau

## Build commands

To be run from cubzh/cubzh repo root dir

**Bash**

```sh
# android
./build.sh -p android
# bazel build //deps/libluau:libluau --platforms=//:android_arm64
# bazel build //deps/libluau:libluau --platforms=//:android_arm
# bazel build //deps/libluau:libluau --platforms=//:android_x86
# bazel build //deps/libluau:libluau --platforms=//:android_x86_64

# ios
./build.sh -p ios
# bazel build //deps/libluau:libluau --platforms=//:ios_arm64

# macos
./build.sh -p macos
# bazel build //deps/libluau:libluau --platforms=//:macos_universal --macos_cpus=arm64,x86_64

# windows
./build.sh -p windows
# bazel build //deps/libluau:libluau --platforms=//:windows_x86
# bazel build //deps/libluau:libluau --platforms=//:windows_x86_64

# linux
# docker run --rm -it -v $(pwd):/cubzh -w /cubzh gcr.io/bazel-public/bazel:8.1.0 build //deps/libluau:libluau --platforms=//:linux_x86
./build.sh -p linux
# bazel build //deps/libluau:libluau --platforms=//:linux_x86
# bazel build //deps/libluau:libluau --platforms=//:linux_x86_64

# wasm
# ./build.sh -p wasm
# bazel build //deps/libluau:libluau --platforms=//:wasm_wasm32
```
