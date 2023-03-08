# chamber-upx

This directory contains latest stable chamber (https://github.com/segmentio/chamber)
binary for linux-amd64 and linux-arm64. It is compressed by upx (https://github.com/upx/upx) so
there's less overhead as possible when copied to a Docker container.

To download chamber and compress it:

```sh
make build
```

To get latest binary and sha256sum copied to current directory:

```sh
make get-chamber-upx
```

Requirements: Docker.
