#!/bin/sh
#
# Copyright 2018 Signal Media Ltd
#
# This is a wrapper for chamber to be used under a Docker container.
# Uses chamber do fetch ENV secrets from AWS SSM Parameter Store and
# supports ENV overrides and extrapolation.
# chamber services are exported from ENV $SECRET_SERVICES.

AWS_REGION=${AWS_REGION:=eu-west-1}
SECRET_SERVICES=${SECRET_SERVICES:=global}
export AWS_REGION=$AWS_REGION

chamber_version="2.8.1"
chamber_url="https://github.com/signal-ai/signal-secret-service/raw/master/chamber-upx/chamber-v${chamber_version}"
chamber_checksum='48e2fe0c2111f82ab2899d00d7a7b4c850a7b2c79e95cdbf85d606b1acc41798  /chamber'


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

if [ ! -f "/chamber" ]; then
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
chamber_env=$(for s in $SECRET_SERVICES ; do /chamber env $s ; done)
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
