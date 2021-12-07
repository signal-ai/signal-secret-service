#!/usr/bin/env sh

set -e

echo
echo "Result environment variables:"
echo

env | grep -E "ROLLBAR_TOKEN|CIRCLECI_TOKEN|OTHER_ENV_VAR"
