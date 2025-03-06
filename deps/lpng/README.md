# libpng

## Build commands (from cubzh/cubzh repo root dir)

### Android

`ANDROID_HOME` and `ANDROID_NDK_HOME` env vars must be defined.

```shell
export ANDROID_HOME="/Users/gaetan/Library/Android/sdk"
export ANDROID_NDK_HOME="/Users/gaetan/Library/Android/sdk/ndk/27.0.11718014"
```

```shell
bazel build --platforms=//:android_armv7 --extra_toolchains=@androidndk//:all //deps/lpng/src:png
bazel build --platforms=//:android_arm64 --extra_toolchains=@androidndk//:all //deps/lpng/src:png
bazel build --platforms=//:android_x86_32 --extra_toolchains=@androidndk//:all //deps/lpng/src:png
bazel build --platforms=//:android_x86_64 --extra_toolchains=@androidndk//:all //deps/lpng/src:png
```

### Linux

```shell
bazel build --platforms=//:linux_arm64 //deps/lpng/src:png
bazel build --platforms=//:linux_x86_64 //deps/lpng/src:png
```

### macOS

```shell
bazel build --platforms=//:macos_arm64 //deps/lpng/src:png
bazel build --platforms=//:macos_x86_64 //deps/lpng/src:png
```

## Products

```
./bazel-out/darwin_arm64-fastbuild/bin/deps/lpng/src/libpng.a
./bazel-out/darwin_arm64-fastbuild/bin/deps/lpng/src/libpng.so
```

## Notes

```shell
ANDROID_HOME="/Users/gaetan/Library/Android/sdk" ANDROID_NDK_HOME="/Users/gaetan/Library/Android/sdk/ndk/27.0.11718014" bazel build --platforms=//:android_arm64 --extra_toolchains=@androidndk//:all //deps/lpng/src:png
```