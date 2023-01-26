FROM --platform=linux/amd64 golang:1.19.5-alpine3.17 AS build-env

COPY go /go

WORKDIR /go/src/website

EXPOSE 80

#################################

FROM --platform=linux/amd64 build-env AS builder

RUN go build

#################################

FROM --platform=linux/amd64 alpine:3.17 AS website

# first copy the resources
COPY content /www 

# then the executable
COPY --from=builder /go/src/website/website /website

EXPOSE 80
WORKDIR /

ENV RELEASE=1

ENTRYPOINT ["/website"]
