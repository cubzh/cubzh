# Unit Tests

## Tests development environment

From repository root directory.

```shell
# Build docker image
docker build -t cubzh-core-unit-tests -f ./common/engine/tests/cubzhCoreUnitTests.Dockerfile .

# Run docker image (bash)
docker run --rm -ti -v $(pwd)/common/engine:/core cubzh-core-unit-tests bash

# Run docker image (Windows PowerShell)
docker run --rm -ti -v $pwd/common/engine:/core cubzh-core-unit-tests bash
```

## Build/Run tests

```shell
# one liner
cmake . && cmake --build . --parallel 2 && ./unit_tests

# cmake .
# cmake --build .
# ./unit_tests
# cmake clean .
```