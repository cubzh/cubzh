# C++ build environment image

This is a Docker image useful for compiling C/C++ code.
It's an Ubuntu LTS, with `clang`, `cmake` and `ninja` programs.

## Build the image locally

```shell
# From the current directory
docker build -t voxowl/cpp-build-env:6.0.0 -f ./Dockerfile .
```

## Build and publish the image for multiple architectures

*Note: you must be logged-in as `voxowl` on the Docker Hub registry*

```shell
# From the current directory
docker buildx build --platform linux/amd64,linux/arm64 -t voxowl/cpp-build-env:6.0.0 -f ./Dockerfile --push .
```
