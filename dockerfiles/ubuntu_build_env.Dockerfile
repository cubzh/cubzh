#
# /dockerfiles/ubuntu_build_env.Dockerfile
#
# Cubzh project
#

FROM ubuntu:22.04 AS env

# architecture of the container itself
# ex: `arm64`, `amd64`, ...
ARG TARGETARCH
ENV CUBZH_ARCH=$TARGETARCH

RUN apt-get update && apt-get install -y cmake clang

COPY /core /core
COPY /deps/libz/linux-ubuntu-$TARGETARCH /deps/libz/linux-ubuntu-$TARGETARCH

WORKDIR /

RUN bash

# -------------------------------------------

# FROM dev-env AS builder

# RUN cmake clean .
# RUN cmake .
# RUN cmake --build .

# -------------------------------------------

# FROM builder AS runner

# RUN ./unit_tests
