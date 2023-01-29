FROM --platform=linux/amd64 golang:1.20.1-alpine3.17 AS build-env

RUN apk update && apk add --no-cache \ 
	git \
	lua5.3 \
	&& rm -rf /var/cache/apk/*

COPY lua/docs/go /go
COPY lua/docs/content /www
COPY lua/docs/parser /parser
COPY lua/modules /modules

RUN cd /parser && ./parse.sh

WORKDIR /go/src/website

EXPOSE 80

#################################

FROM --platform=linux/amd64 build-env AS builder

RUN go build

#################################
# This is like a production server but hot-refreshing 
# of content is available for documentation-writing purposes.

FROM --platform=linux/amd64 alpine:3.17 AS website-dev

# first copy the resources
COPY content /www 

# then the executable
COPY --from=builder /webserver/webserver /webserver

EXPOSE 80
WORKDIR /

ENTRYPOINT ["/webserver"]

#################################
# This is a production webserver.
# Content is cached (content hot-refreshing is not available).

FROM --platform=linux/amd64 website-dev AS website

ENV RELEASE=1
