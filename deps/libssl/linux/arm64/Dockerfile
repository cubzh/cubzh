FROM --platform=linux/arm64 ubuntu:22.04

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*

CMD ["bash"]