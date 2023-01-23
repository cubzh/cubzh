# Cubzh CLI - compilation with CMake

## How-to

```shell
cd ./cli/cmake
cmake .
cmake --build .
# alternative to force a rebuild
cmake --build . --clean-first
```

**Alternative using `Ninja`**

```shell
cd ./cli/cmake
cmake -G Ninja .
cmake --build .
# alternative to force a rebuild
cmake --build . --clean-first
```

## Using Docker

```shell
# From repo root directory
docker build -t cli-build -f ./cli/cmake/Dockerfile .
```