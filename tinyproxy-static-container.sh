#!/bin/sh
# This script builds a statically compiled Tinyproxy from either the latest release or the Git repository.
# It uses Buildah to create two container images, an Alpine build environment, and a minimal scratch container with the compiled binary.

set -e  # Exit immediately if a command exits with a non-zero status.

# Inform the user we are starting the build process
echo "Starting build process: Preparing build environments..."

build0=$(buildah from alpine:3)  # Create a new container from Alpine base image.
echo "Created Alpine build container: $build0"

build1=$(buildah from scratch)  # Create a new scratch container.
echo "Created empty scratch container: $build1"

# Mount both build containers
echo "Mounting build containers..."
build0mnt=$(buildah mount "$build0")
echo "Mounted Alpine build container at: $build0mnt"

build1mnt=$(buildah mount "$build1")
echo "Mounted scratch container at: $build1mnt"

# Common preparation: installing dependencies
echo "Installing dependencies in Alpine build container..."
buildah run "$build0" sh -c 'apk add -q --no-cache automake linux-headers alpine-sdk libtool pcre-dev zlib-dev autoconf curl jq git'
echo "Dependencies installed successfully."

# Function to configure, build, and install Tinyproxy
build_and_install() {
  echo "Configuring, building, and installing Tinyproxy..."
  buildah run "$build0" sh -c "cd /tmp/tinyproxy/; \
   ./autogen.sh; \
    CFLAGS='-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIE' \
    CPPFLAGS='-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIE' \
    LDFLAGS='-static -Wl,-z,relro,-z,now' \
    ./configure; \
    make; \
    make install; \
    strip /usr/local/bin/tinyproxy"
  echo "Tinyproxy build and installation completed."
}

if [ "$#" -eq 0 ] || [ "${1^^}" != "GIT" ]; then
  # Download and build from the latest release tarball
  echo "Downloading Tinyproxy release tarball..."
  buildah run "$build0" sh -c 'REPO="tinyproxy/tinyproxy"; \
  LATEST_RELEASE=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest"); \
  TARBALL_URL=$(echo $LATEST_RELEASE | jq -r ".assets[].browser_download_url" | grep tar.gz); \
  curl -L $TARBALL_URL | tar -xz -C /tmp; \
  SUBDIR=$(find /tmp/ -mindepth 1 -maxdepth 1 -type d); \
  mv $SUBDIR /tmp/tinyproxy'
  echo "Downloaded and extracted Tinyproxy release tarball."

  # Attempt to read VERSION file, or set default version
  VERSION=$(buildah run "$build0" sh -c 'cat /tmp/tinyproxy/VERSION')
  echo "Using Tinyproxy version: ${VERSION:-unknown}"
  build_and_install

else
  # Clone and build from the Git repository
  echo "Cloning Tinyproxy Git repository..."
  VERSION=$(buildah run "$build0" sh -c 'git clone https://github.com/tinyproxy/tinyproxy.git /tmp/tinyproxy && \
  cd /tmp/tinyproxy && \
  git rev-parse HEAD' | cut -c1-7)
  echo "Cloned Tinyproxy repository, using commit: $VERSION"
  build_and_install
fi

# Copy the binary to the scratch image and unmount
echo "Copying Tinyproxy binary to scratch container..."
cp $build0mnt/usr/local/bin/tinyproxy $build1mnt/tinyproxy
echo "Tinyproxy binary copied successfully."

# Unmount build containers
echo "Unmounting build containers..."
buildah unmount "$build0" "$build1"
echo "Build containers unmounted."

# Set the entrypoint and working directory
echo "Configuring the scratch container with entrypoint and labels..."
buildah config --cmd '"/tinyproxy", "-d", "-c", "/config.txt"' --workingdir /config "$build1"
buildah config --label "maintainer=Brian Barnes-Cocke <Brian@brian.com>" "$build1"
buildah config --label "org.opencontainers.image.title=Tinyproxy Scratch Container" "$build1"
buildah config --label "org.opencontainers.image.description=Statically compiled Tinyproxy built in scratch container" "$build1"
buildah config --label "org.opencontainers.image.url=https://github.com/babarnescocke/tinyproxy-static-container" "$build1"
buildah config --label "org.opencontainers.image.source=https://github.com/babarnescocke/tinyproxy-static-container" "$build1"
buildah config --label "org.opencontainers.image.licenses=MIT" "$build1"
buildah config --label "org.opencontainers.image.version=${VERSION:-unknown}" "$build1"  # Add dynamic version label

echo "Committing the final Tinyproxy image..."
buildah commit --squash --disable-compression=false --rm "$build1" tinyproxy-static-container
echo "Tinyproxy static container image built successfully."

