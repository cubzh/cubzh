# Luau

## Build commands

To be run from cubzh/cubzh repo root dir

**Bash**

```sh
# android
./build.sh -p android
# bazel build //deps/luau:luau --platforms=//:android_arm64
# bazel build //deps/luau:luau --platforms=//:android_armv7
# bazel build //deps/luau:luau --platforms=//:android_x86_32
# bazel build //deps/luau:luau --platforms=//:android_x86_64

# ios
./build.sh -p ios
# bazel build //deps/luau:luau --platforms=//:ios_arm64

# macos
./build.sh -p macos
# bazel build //deps/luau:luau --platforms=//:macos_arm64
# bazel build //deps/luau:luau --platforms=//:macos_x86_64

# windows
./build.sh -p windows
# bazel build //deps/luau:luau --platforms=//:windows_x86_32
# bazel build //deps/luau:luau --platforms=//:windows_x86_64

# linux
# ./build.sh -p linux
# bazel build //deps/luau:luau --platforms=//:linux_x86_32
# bazel build //deps/luau:luau --platforms=//:linux_x86_64

# wasm
# ./build.sh -p wasm
# bazel build //deps/luau:luau --platforms=//:wasm_wasm32
```
