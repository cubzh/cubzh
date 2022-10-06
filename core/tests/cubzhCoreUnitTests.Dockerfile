FROM ubuntu:22.04 AS env

# platform of the container itself
# ex: `linux/arm64`, `linux/amd64`
ARG TARGETPLATFORM
ENV DOCKER_TARGETPLATFORM=$TARGETPLATFORM

RUN apt-get update && apt-get install -y cmake clang

COPY /common/engine /core
COPY /deps/libz /deps/libz

WORKDIR /core/tests

RUN bash

# -------------------------------------------

# FROM dev-env AS builder

# RUN cmake clean .
# RUN cmake .
# RUN cmake --build .

# -------------------------------------------

# FROM builder AS runner

# RUN ./unit_tests
