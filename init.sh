#!/bin/sh
#
# Copyright 2018, 2019, 2020, 2021, 2022 Signal Media Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# This is a wrapper for chamber to be used under a Docker container.
# Uses chamber do fetch ENV secrets from AWS SSM Parameter Store and
# supports ENV overrides and extrapolation.
# chamber services are exported from ENV $SECRET_SERVICES.

AWS_REGION=${AWS_REGION:=eu-west-1}
SECRET_SERVICES=${SECRET_SERVICES:=global}
export AWS_REGION=$AWS_REGION

chamber_version="2.12.0"
case $(uname -m) in
  "amd64" | "x64_64")
    chamber_url="https://github.com/signal-ai/signal-secret-service/raw/multiarch/chamber-upx/chamber-v${chamber_version}-linux-amd64"
    chamber_checksum='ad4a6bfe75078be65507c2974f0a8517c346cf2b91538eedce10baccfa3e2aeb  /chamber'
    ;;
  "arm64" | "aarch64")
    chamber_url="https://github.com/signal-ai/signal-secret-service/raw/multiarch/chamber-upx/chamber-v${chamber_version}-linux-arm64"
    chamber_checksum='6a1cbefea09f2fbf2169c18aed57411c7d67a4035c1ae89c8e1cf0f180fbf8c0  /chamber'
    ;;
  *)
    echo "Cannot run chamber: unsupported hardware platform $(uname -m)"
    exit 1
    ;;
esac

if [ ! -f "/chamber" ]; then
    # Install chamber using curl
    curl -V > /dev/null 2>&1
    curl_status=$?
    if [ $curl_status = 127 ]; then
        if [ -f "/etc/alpine-release" ]; then
            echo "Alpine Linux detected. Installing curl..."
            apk --update add curl
        else
           echo "No curl installed. chamber will not be downloaded."
           exit 1
        fi
    fi

    echo "Downloading chamber from $chamber_url"
    echo "$chamber_checksum" > /sha256sum.txt
    curl -f -L $chamber_url -o /chamber
    curl_status=$?
    if [ $curl_status != 0 ]; then
        echo "Could not download chamber."
        exit 1
    fi
    sha256sum -c /sha256sum.txt
    checksum_status=$?
    if [ $checksum_status != 0 ]; then
        echo "Checksum failed"
        exit 1
    fi
    chmod +x /chamber
fi

if [ $# -eq 0 ]; then
    echo "No arguments supplied"
    exit
fi

eval_export() {
    to_export="$@"
    keys=$(for v in $to_export ; do echo $v | awk -F '=' '{print $1}' ; done)
    echo $keys
    eval export $to_export
}

# Get list of ENV variables injected by Docker
echo "Getting ENV variables..."
original_variables=$(export | cut -f2 -d ' ')

# Call chamber with services from ENV $SECRET_SERVICES and export decrypted ENV variables
echo "Fetching ENV secrets with chamber for systems $SECRET_SERVICES..."

# We have to loop through $SECRET_SERVICES because 'chamber env' doesn't support
# multiple services
chamber_env=$(for s in $SECRET_SERVICES ; do /chamber env $s || rc=$? ; done ; exit $rc)
chamber_result=$?

if [ $chamber_result != 0 ]; then
    echo "Chamber failed to get secrets for service: $SECRET_SERVICES"
    if [ ! -z $AWS_EXECUTION_ENV ]; then
        echo "Running in AWS. Exiting."
        exit 1
    fi
fi

# We want to remove 'export' from the env output and also convert - into _ for env names
to_secrets=$(echo $chamber_env | sed 's/export //g' | for e in $(cat -) ; do echo $e | awk '{ gsub("-", "_", $1) } 1' FS='=' OFS='='; done)
eval_export $to_secrets

# Perform overrides
to_override=$(for k in $keys ; do for v in $original_variables ; do echo $v |grep ^$k |grep -v SECRET ; done ; done)
if [ ! -z "$to_override" -a "$to_override" != " " ]; then
    echo "Applying ENV overrides..."
    eval_export $to_override
fi

# Perform variable extrapolation
secret_keys=$(for v in $to_secrets ; do echo $v | awk -F '=' '{print $1}' ; done)
to_extrapolate=$(for k in $secret_keys ; do env |grep "\$$k" ; done | uniq | sed 's/\(=[[:blank:]]*\)\(.*\)/\1"\2"/')
if [ ! -z "$to_extrapolate" -a "$to_extrapolate" != " " ]; then
    echo "Applying ENV extrapolation..."
    eval_export $to_extrapolate
fi

echo "Starting $@..."
exec "$@"
