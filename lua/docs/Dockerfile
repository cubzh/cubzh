FROM --platform=linux/amd64 golang:1.15.3-alpine3.12 AS build-env

RUN apk update && apk add --no-cache \ 
	git \
	&& rm -rf /var/cache/apk/*

COPY go /go
COPY content /www

WORKDIR /go/src/website

EXPOSE 80
ENTRYPOINT ["ash"]

#################################

FROM --platform=linux/amd64 golang:1.15.3-alpine3.12 AS builder

RUN apk update && apk add --no-cache \ 
	git \
	&& rm -rf /var/cache/apk/*

COPY --from=build-env /go /go
COPY --from=build-env /www /www

EXPOSE 80
WORKDIR /go/src/website

RUN go build

ENTRYPOINT ["./website"]

#################################

FROM --platform=linux/amd64 alpine:3.12 AS website

COPY --from=builder /go/src/website/website /website
COPY --from=builder /www /www

EXPOSE 80
WORKDIR /

ENV RELEASE=1

ENTRYPOINT ["/website"]

