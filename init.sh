#!/bin/sh
# This is a wrapper for chamber to be used under a Docker container.
# Uses chamber do fetch ENV secrets from EC2 Parameter Store and
# supports ENV overrides and extrapolation.
# chamber services are exported from ENV $SECRET_SERVICES.

curl=$(which curl)
chamber_version="2.0.0"
chamber_url="https://github.com/segmentio/chamber/releases/download/v${chamber_version}/chamber-v${chamber_version}-linux-amd64"

if [ ! -f "/chamber" ]; then
    echo "Downloading chamber from $chamber_url"
    $curl -L $chamber_url -o /chamber
    chmod +x /chamber
fi

if [ $# -eq 0 ]; then
    echo "No arguments supplied"
    exit
fi

AWS_REGION=${AWS_REGION:=eu-west-1}
SECRET_SERVICES=${SECRET_SERVICES:=global}
export AWS_REGION=$AWS_REGION

eval_export() {
    to_export=$1
    keys=$(for v in $to_export ; do echo $v | awk -F '=' '{print $1}' ; done)
    echo $keys
    eval export $to_export
}

# Get list of ENV variables injected by Docker
echo "Getting ENV variables..."
original_variables=$(export | awk -F ' ' '{print $3}')

# Call chamber with services from ENV $SECRET_SERVICES and export decrypted ENV variables
echo "Fetching ENV secrets with chamber..."
to_secrets=$(/chamber export $SECRET_SERVICES -f dotenv | sed 's/\(=[[:blank:]]*\)\(.*\)/\1"\2"/')
eval_export $to_secrets

# Perform overrides
to_override=$(for k in $keys ; do for v in $original_variables ; do echo $v |grep $k |grep -v SECRET ; done ; done)
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
"$@"
