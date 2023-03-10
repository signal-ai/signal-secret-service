image = chamber-upx:$(chamber_version)
current_dir = $(shell pwd)
chamber_version = 2.12.0

get-chamber-upx:
	docker run --mount type=bind,source=$(current_dir),target=/mnt --rm -it $(image) cp /chamber-v$(chamber_version)-linux-amd64 /chamber-v$(chamber_version)-linux-amd64-sha256sum.txt /chamber-v$(chamber_version)-linux-arm64 /chamber-v$(chamber_version)-linux-arm64-sha256sum.txt /mnt/

build:
	docker build -t $(image) .

.PHONY: build get-chamber-upx
