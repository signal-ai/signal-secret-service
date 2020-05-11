# Alpine base image
FROM alpine:3.11
# Download upx
ENV upx 3.96
ADD https://github.com/upx/upx/releases/download/v${upx}/upx-${upx}-amd64_linux.tar.xz /usr/local
RUN xz -d -c /usr/local/upx-${upx}-amd64_linux.tar.xz | \
    tar -xOf - upx-${upx}-amd64_linux/upx > /bin/upx && \
    chmod a+x /bin/upx
# Download chamber
ENV chamber 2.8.1
ADD https://github.com/segmentio/chamber/releases/download/v${chamber}/chamber-v${chamber}-linux-amd64 /chamber-v${chamber}
RUN chmod +x /chamber-v${chamber}
# Compress chamber
RUN upx --brute /chamber-v${chamber}
# Generate checksum
RUN sha256sum /chamber-v${chamber} > /chamber-v${chamber}-sha256sum.txt
