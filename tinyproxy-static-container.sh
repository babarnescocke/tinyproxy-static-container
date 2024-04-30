#!/bin/sh
build0=$(buildah from alpine:3)
build0mnt=$(buildah mount "$build0")
build1=$(buildah from scratch)
build1mnt=$(buildah mount "$build1")
# Provide logic to build either git or latest release

if [[ "$#" -eq 0 || "${1^^}" == "LATEST" ]]
then
buildah run "$build0" sh -c 'apk add -q --no-cache automake linux-headers alpine-sdk libtool pcre-dev zlib-dev autoconf &&\
  git clone https://github.com/tinyproxy/tinyproxy.git &&\
  cd tinyproxy;
  ./autogen.sh;
  LDFLAGS="-static" ./configure;
  make;
  make install;
  strip /local/usr/bin/tinyproxy'
cp $build0mnt/local/usr/bin/tinyproxy $build1mnt
buildah unmount $build1mnt $build0mnt
buildah config --entrypoint '[ "tinyproxy","-d","-c","/config.txt"]' \
 --workingdir /config "$build1"
buildah commit --squash --disable-compression=false --rm "$build1" tinyproxy-scratch-container
else
buildah run "$build0" sh -c 'apk add -q --no-cache automake linux-headers alpine-sdk libtool pcre-dev zlib-dev autoconf curl; \
  REPO="tinyproxy/tinyproxy"; \
  LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases/latest"); \
  TARBALL_URL=$(echo $LATEST_RELEASE | grep tarball_url | cut -d '"' -f 4); \
  curl -L $TARBALL_URL | tar zx; \
  cd tinyproxy; \
  ./autogen.sh;
  LDFLAGS="-static" ./configure;
  make;
  make install;
  strip /local/usr/bin/tinyproxy'
cp $build0mnt/local/usr/bin/tinyproxy $build1mnt
buildah unmount $build1mnt $build0mnt
buildah config --entrypoint '[ "tinyproxy","-d","-c","/config.txt"]' \
 --workingdir /config "$build1"
buildah commit --squash --disable-compression=false --rm "$build1" tinyproxy-scratch-container

fi
