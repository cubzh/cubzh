# libpng

## Build commands (from cubzh/cubzh repo root dir)

```shell
bazel build --platforms=//:android_armv7 //deps/lpng/src:png
bazel build --platforms=//:android_arm64 //deps/lpng/src:png
bazel build --platforms=//:android_x86_32 //deps/lpng/src:png
bazel build --platforms=//:android_x86_64 //deps/lpng/src:png
```

## Products

```
./bazel-out/darwin_arm64-fastbuild/bin/deps/lpng/src/libpng.a
./bazel-out/darwin_arm64-fastbuild/bin/deps/lpng/src/libpng.so
```
