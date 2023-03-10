#!/bin/sh -x
# This script is used by docker to fetch the latest zig master tarball
BRANCH=master
ARCH=`uname -m`-linux
URL=$(curl -s https://ziglang.org/download/index.json | jq --arg BRANCH $BRANCH '.[$BRANCH]' | jq -r --arg ARCH $ARCH '.[$ARCH].tarball')
#curl --output zig.tar.xz $URL
echo $URL
