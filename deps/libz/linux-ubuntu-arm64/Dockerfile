FROM --platform=linux/arm64 ubuntu:22.04

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

CMD ["bash"]