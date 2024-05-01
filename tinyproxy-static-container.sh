#!/bin/sh
set -e  # Exit immediately if a command exits with a non-zero status.

build0=$(buildah from alpine:3)
build1=$(buildah from scratch)

# Mount both build containers
build0mnt=$(buildah mount "$build0")
build1mnt=$(buildah mount "$build1")

# Common preparation: installing dependencies
buildah run "$build0" sh -c 'apk add -q --no-cache automake linux-headers alpine-sdk libtool pcre-dev zlib-dev autoconf curl  jq'

# Function to configure, build, and install Tinyproxy
build_and_install() {
  buildah run "$build0" sh -c "cd /tmp/tinyproxy/; \
   ./autogen.sh; \
    LDFLAGS='-static' ./configure; \
    make; \
    make install; \
    strip /usr/local/bin/tinyproxy"
}

if [ "$#" -eq 0 ] || [ "${1^^}" != "GIT" ]; then
  # Download and build from the latest release tarball
  buildah run "$build0" sh -c '  REPO="tinyproxy/tinyproxy"; \
  LATEST_RELEASE=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest"); \
  TARBALL_URL=$(echo $LATEST_RELEASE | jq -r '.assets[].browser_download_url' | grep tar.gz); \curl -L $TARBALL_URL | tar -xz -C /tmp; \
  subdir=$(find /tmp/ -mindepth 1 -maxdepth 1 -type d); \
   mv $subdir /tmp/tinyproxy'
  build_and_install
  IMAGE_TAG="tinyproxy-scratch-container:latest"
else
  # Clone and build from the Git repository
  buildah run "$build0" sh -c 'git clone https://github.com/tinyproxy/tinyproxy.git /tmp/tinyproxy'
  build_and_install
  IMAGE_TAG="tinyproxy-scratch-container:git"
fi

# Copy the binary to the scratch image and unmount
cp $build0mnt/usr/local/bin/tinyproxy $build1mnt/tinyproxy
buildah unmount "$build0" "$build1"  # Use container names here

# Set the entrypoint and working directory
buildah config --entrypoint '["tinyproxy", "-d", "-c", "/config.txt"]' --workingdir /config "$build1"
buildah commit --squash --disable-compression=false --rm "$build1" "$IMAGE_TAG"

