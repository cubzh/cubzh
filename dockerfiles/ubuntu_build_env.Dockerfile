#
# /dockerfiles/ubuntu_build_env.Dockerfile
#
# Cubzh project
#

FROM voxowl/cpp-build-env:14.0.0

# architecture of the container itself
# ex: `arm64`, `amd64`, ...
ARG TARGETARCH
ENV CUBZH_ARCH=$TARGETARCH

COPY /core /core
COPY /deps/libz/linux-ubuntu-$TARGETARCH /deps/libz/linux-ubuntu-$TARGETARCH

WORKDIR /

# -------------------------------------------

# FROM dev-env AS builder

# RUN cmake clean .
# RUN cmake .
# RUN cmake --build .

# -------------------------------------------

# FROM builder AS runner

# RUN ./unit_tests
