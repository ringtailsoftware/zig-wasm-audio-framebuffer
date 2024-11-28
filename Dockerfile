FROM alpine:latest
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
RUN apk add python3
WORKDIR /data
EXPOSE 8000
