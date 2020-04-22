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

chamber_version="2.0.0"
chamber_url="https://github.com/segmentio/chamber/releases/download/v${chamber_version}/chamber-v${chamber_version}-linux-amd64"
chamber_checksum='bdff59df90a135ea485f9ce5bcfed2b3b1cc9129840f08ef9f0ab5309511b224  /chamber'


echo "$chamber_checksum" > /sha256sum.txt

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

secret_env=$(/tmp/chamber export $SECRET_SERVICES -f dotenv)

chamber_result=$?
if [ $chamber_result != 0 ]; then
    echo "Chamber failed to get secrets for service: $SECRET_SERVICES"
    exit 1
fi

to_secrets=$(echo "$secret_env" | sed 's/\(=[[:blank:]]*\)\(.*\)/\1"\2"/')
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
