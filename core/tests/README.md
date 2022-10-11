# Unit Tests

## Tests development environment

From repository root directory.

```shell
# Build docker image
docker build -t cubzh-core-unit-tests -f ./dockerfiles/ubuntu_build_env.Dockerfile .

# Run docker image (bash)
docker run --rm -ti -v $(pwd)/core:/core cubzh-core-unit-tests bash

# Run docker image (Windows PowerShell)
docker run --rm -ti -v $pwd/core:/core cubzh-core-unit-tests bash
```

## Build/Run tests

```shell
# one liner
cd /core/tests/cmake && cmake . && cmake --build . --parallel 2 && ./unit_tests

# cmake .
# cmake --build .
# ./unit_tests
# cmake clean .
```