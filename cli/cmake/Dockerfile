FROM voxowl/cpp-build-env:18.1.3 AS build-env

COPY . /cubzh

WORKDIR /cubzh/cli/cmake

RUN CC=clang CXX=clang++ cmake -G Ninja .
RUN cmake --build . --clean-first

# binary is /cubzh/cli/cmake/cubzh_cli
