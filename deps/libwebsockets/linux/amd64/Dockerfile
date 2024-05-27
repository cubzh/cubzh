# NOTE: BUILD THIS IMAGE FROM /deps CONTEXT

FROM --platform=linux/amd64 ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  clang \
  cmake \
  ninja-build \
  ca-certificates \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir /ws
RUN git clone --depth 1 --branch v4.3.1 https://github.com/warmcat/libwebsockets /ws/libwebsockets

WORKDIR /ws/libwebsockets/build

RUN cmake -G Ninja ..

RUN cmake --build . --parallel 4

CMD ["bash"]
