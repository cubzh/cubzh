FROM --platform=linux/amd64 debian:bullseye

RUN echo "deb http://ftp.debian.org/debian stretch-backports main" > /etc/apt/sources.list.d/stretch-backports.list

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

CMD ["bash"]