# --------------------------------------------------
# Build env for WASM app
# --------------------------------------------------

# important : emsdk don't work on arm64 platform (as of now)
FROM --platform=amd64 voxowl/emsdk:3.1.38 AS wasm_build_env

# COPY REQUIRED FILES TO BUILD THE APP

COPY ./common/assets /repo/common/assets
COPY ./common/bgfx /repo/common/bgfx
COPY ./common/kiwi /repo/common/kiwi
COPY ./common/Lua /repo/common/Lua
COPY ./common/VXFramework /repo/common/VXFramework
COPY ./common/VXGameServer /repo/common/VXGameServer
COPY ./common/VXLuaSandbox /repo/common/VXLuaSandbox
COPY ./common/VXNetworking /repo/common/VXNetworking

COPY ./deps /repo/deps

COPY ./wasm/Particubes /repo/wasm/Particubes

# Cubzh Core
COPY ./cubzh/core /repo/cubzh/core
COPY ./cubzh/deps /repo/cubzh/deps
COPY ./cubzh/lua/modules /repo/cubzh/lua/modules
COPY ./cubzh/i18n /repo/cubzh/i18n

COPY ./cubzh/deps/xptools /repo/xptools

# -------------------------------------

WORKDIR /repo/wasm/Particubes

CMD bash -c "source /emsdk/emsdk_env.sh; bash"

# --------------------------------------------------
# Build WASM app
# --------------------------------------------------

FROM wasm_build_env AS builder

# compile wasm application
RUN /bin/bash -c "source /emsdk/emsdk_env.sh && ./build.sh"

CMD bash

# --------------------------------------------------
# Build Go HTTP server
# --------------------------------------------------

FROM --platform=amd64 golang:1.22.2-alpine3.19 AS http_builder

# for HTTPS
# /cubzh/certificates

# context is root of the git repo

COPY ./go/cu.bzh/cors /go/cu.bzh/cors
COPY ./go/cu.bzh/wasmserver /go/cu.bzh/wasmserver

WORKDIR /go/cu.bzh/wasmserver

RUN go build main.go

CMD ash

# --------------------------------------------------
# web server runner | empty : no website files
# --------------------------------------------------
FROM --platform=amd64 alpine:3.19 AS web_server_empty

# get the http server executable
COPY --from=http_builder /go/cu.bzh/wasmserver/main /server

# SSL/TLS certificates for HTTPS
# /cubzh/certificates

CMD /server

# --------------------------------------------------
# Dev environment for the Go HTTP server
# --------------------------------------------------
# Useful to dev the Go http server itself.
# Contains:
#   - SSL/TLS certificates for HTTPS
#   - Go compiler
#   - Go source of http server for wasm app
#   - a compiled copy of Cubzh wasm app
FROM --platform=amd64 golang:1.22.2-alpine3.19 AS http_server_dev_env
# SSL/TLS certificates for HTTPS
# /cubzh/certificates
# context is root of the git repo
COPY ./go/cu.bzh/wasmserver /go/cu.bzh/wasmserver
# compiled Cubzh wasm app
COPY --from=builder /repo/wasm/Particubes/build/output /www

WORKDIR /go/cu.bzh/wasmserver

CMD ash

# --------------------------------------------------
# web server runner
# --------------------------------------------------
FROM web_server_empty

# compiled Cubzh wasm app
COPY --from=builder /repo/wasm/Particubes/build/output /www
