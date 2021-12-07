.PHONY:
test:
	@echo "Running amazon linux 2..."
	@docker build . -f Dockerfile.al2 -t signal-secret-service-al2
	@docker run \
		-e AWS_PROFILE=signal-prod \
		-e ROLLBAR_TOKEN=SECRET \
		-e CIRCLECI_TOKEN=SECRET \
		-e OTHER_ENV_VAR=test_var \
		-v $$HOME/.aws:/root/.aws \
		--rm \
		signal-secret-service-al2
	@echo

	@echo "Running alpine..."
	@docker build . -f Dockerfile.alpine -t signal-secret-service-alpine
	@docker run \
		-e AWS_PROFILE=signal-prod \
		-e ROLLBAR_TOKEN=SECRET \
		-e CIRCLECI_TOKEN=SECRET \
		-e OTHER_ENV_VAR=test_var \
		-v $$HOME/.aws:/root/.aws \
		--rm \
		signal-secret-service-alpine
	@echo

	@echo "Running debian"
	@docker build . -f Dockerfile.debian -t signal-secret-service-debian
	@docker run \
		-e AWS_PROFILE=signal-prod \
		-e ROLLBAR_TOKEN=SECRET \
		-e CIRCLECI_TOKEN=SECRET \
		-e OTHER_ENV_VAR=test_var \
		-v $$HOME/.aws:/root/.aws \
		--rm \
		signal-secret-service-debian
