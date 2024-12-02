# Use Alpine as the base image for the build stage
FROM alpine:3 as builder

# Install necessary packages
RUN apk add --no-cache automake linux-headers alpine-sdk libtool pcre-dev zlib-dev autoconf curl jq

# Add a conditional argument to switch between Git clone and tarball download
ARG SOURCE_TYPE

# Common steps for both build paths: download source code
# If SOURCE_TYPE is not 'GIT', download from release tarball
RUN if [ "$SOURCE_TYPE" != "GIT" ]; then \
      REPO="tinyproxy/tinyproxy"; \
      LATEST_RELEASE=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest"); \
      TARBALL_URL=$(echo $LATEST_RELEASE | jq -r '.assets[].browser_download_url' | grep tar.gz); \
      curl -L $TARBALL_URL | tar -xz -C /tmp; \
      SUBDIR=$(find /tmp/ -mindepth 1 -maxdepth 1 -type d); \
      mv $SUBDIR /tmp/tinyproxy; \
    else \
      git clone https://github.com/tinyproxy/tinyproxy.git /tmp/tinyproxy; \
    fi

# Configure, build, and install Tinyproxy
WORKDIR /tmp/tinyproxy
RUN ./autogen.sh && \
    CFLAGS="-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIE -fPIC -Wl,-z,relro,-z,now -static" \
    CPPFLAGS="-O2 -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fPIE -fPIC" \
    LDFLAGS="-static -Wl,-z,relro,-z,now" ./configure && \
    make && \
    make install && \
    strip /usr/local/bin/tinyproxy

# Start from a scratch image for a minimal final image
FROM scratch

# Copy the Tinyproxy binary from the build stage
COPY --from=builder /usr/local/bin/tinyproxy /tinyproxy

# Set the entrypoint and working directory
WORKDIR /config
CMD ["/tinyproxy", "-d", "-c", "/config.txt"]

LABEL maintainer="Brian Barnes-Cocke <Brian@brian.com>" \
      org.opencontainers.image.title="Tinyproxy Scratch Container" \
      org.opencontainers.image.description="Statically compiled Tinyproxy built in scratch container" \
      org.opencontainers.image.url="https://github.com/babarnescocke/tinyproxy-static-container" \
      org.opencontainers.image.source="https://github.com/babarnescocke/tinyproxy-static-container" \
      org.opencontainers.image.licenses="MIT"
