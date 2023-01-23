FROM voxowl/cpp-build-env:14.0.0 AS build-env

COPY . /cubzh

WORKDIR /cubzh/cli/cmake

RUN CC=clang CXX=clang++ cmake -G Ninja .
RUN cmake --build . --clean-first

# binary is /cubzh/cli/cmake/cubzh_cli
