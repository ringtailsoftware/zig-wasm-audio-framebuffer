FROM alpine:latest
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
RUN apk add jq curl python3
RUN mkdir /zig
COPY . /zig
WORKDIR /zig
RUN curl --output zig.tar.xz `./fetch-zig-url.sh`
RUN tar xf zig.tar.xz
RUN mv zig-linux* zig-linux
ENV PATH="${PATH}:/zig/zig-linux"
EXPOSE 8000
CMD zig build && (cd zig-out && python3 -m http.server 8000)
