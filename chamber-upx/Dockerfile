# Alpine base image
FROM alpine:3.11
# Download upx
ENV upx 3.96
ADD https://github.com/upx/upx/releases/download/v${upx}/upx-${upx}-arm64_linux.tar.xz /usr/local
RUN xz -d -c /usr/local/upx-${upx}-arm64_linux.tar.xz | \
    tar -xOf - upx-${upx}-arm64_linux/upx > /bin/upx && \
    chmod a+x /bin/upx
# Download chamber
ENV chamber 2.12.0

ADD https://github.com/segmentio/chamber/releases/download/v${chamber}/chamber-v${chamber}-linux-amd64 /chamber-v${chamber}-linux-amd64
RUN chmod +x /chamber-v${chamber}-linux-amd64
# Compress chamber
RUN upx --brute /chamber-v${chamber}-linux-amd64
# Generate checksum
RUN sha256sum /chamber-v${chamber}-linux-amd64 > /chamber-v${chamber}-linux-amd64-sha256sum.txt

ADD https://github.com/segmentio/chamber/releases/download/v${chamber}/chamber-v${chamber}-linux-arm64 /chamber-v${chamber}-linux-arm64
RUN chmod +x /chamber-v${chamber}-linux-arm64
# Compress chamber
RUN upx --brute /chamber-v${chamber}-linux-arm64
# Generate checksum
RUN sha256sum /chamber-v${chamber}-linux-arm64 > /chamber-v${chamber}-linux-arm64-sha256sum.txt
