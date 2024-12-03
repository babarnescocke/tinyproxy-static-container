# Tinyproxy Static Container

This project provides an OCI-compliant container image for [Tinyproxy](https://github.com/tinyproxy/tinyproxy), a lightweight and fast HTTP/HTTPS proxy daemon. The main goal of this project was to explore the process of statically compiling an arbitrary C program and packaging it into a minimal container image. Along the way, I added some security enhancements (like Position Independent Executables (PIE) and other linker options) because having a "belt and suspenders" approach to security is always nice.

## Features

- **Statically compiled**: The Tinyproxy binary is statically compiled to ensure a minimal runtime dependency footprint.
- **Minimal base image**: Built on `scratch` for a minimal container size.
- **Enhanced security**:
  - Built with `-fstack-protector-strong` and `-D_FORTIFY_SOURCE=2` to guard against stack overflows.
  - Uses `-z relro,now` to improve runtime relocation and symbol resolution security.

## Usage

### Build Container Image

You can build the image using Docker:

```bash
buildah bud -t tinyproxy-static-container .
```

You can then run the image:

```bash
podman run --rm -v $(pwd)/config.txt:/config.txt -p 8888:8888/tcp tinyproxy-static-container
```

Ensure you have a valid `config.txt` file in your working directory for Tinyproxy's configuration.

### Buildah Script

For those using Buildah to build the container, the process differs slightly, especially if you’re running Buildah as a non-root user. The steps are:

1. **Clone this repository**:
   ```bash
   git clone https://github.com/babarnescocke/tinyproxy-static-container.git
   cd tinyproxy-static-container
   ```

2. **Run the script in an unshared user namespace** (for non-root users):
   ```bash
   buildah unshare ./tinyproxy-static-container.sh
   ```

3. **Specify the build source**:
   - To build from the latest release tarball:
     ```bash
     buildah bud -t tinyproxy-static-container ./
     ```
   - To build from the Git repository:
     ```bash
     buildah unshare ./tinyproxy-static-container.sh GIT
     ```

4. **Run the container**:
   ```bash
   podman run --rm -v $(pwd)/config.txt:/config.txt -p 8888:8888/tcp tinyproxy-static-container
   ```

## Upstream Project

This project is based on the upstream Tinyproxy project, which can be found at: [https://github.com/tinyproxy/tinyproxy](https://github.com/tinyproxy/tinyproxy).

## License

This container image and source are licensed under the [MIT License](https://opensource.org/licenses/MIT). For details, see the `LICENSE` file in the Tinyproxy repository.
