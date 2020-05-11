image = chamber-upx:$(chamber_version)
current_dir = $(shell pwd)
chamber_version = 2.8.1

get-chamber-upx:
	docker run --mount type=bind,source=$(current_dir),target=/mnt --rm -it $(image) cp /chamber-v$(chamber_version) /chamber-v$(chamber_version)-sha256sum.txt /mnt/

build:
	docker build -t $(image) .

.PHONY: build get-chamber-upx
