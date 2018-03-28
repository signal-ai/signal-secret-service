#!/bin/bash

AWS_REGION=${AWS_REGION:=eu-west-1}
SECRET_SERVICES=${SECRET_SERVICES:=global}
export AWS_REGION=$AWS_REGION

echo "Extracting secrets with chamber..."
to_export=$(/chamber export $SECRET_SERVICES -f dotenv | sed 's/\(=[[:blank:]]*\)\(.*\)/\1"\2"/')
keys=$(for v in $to_export ; do echo $v | awk -F '=' '{print $1}' ; done)
echo $keys
eval export $to_export

to_extrapolate=$(for k in $keys ; do env |grep "\$$k" ; done | uniq | sed 's/\(=[[:blank:]]*\)\(.*\)/\1"\2"/')
if [ ! -z "$to_extrapolate" -a "$to_extrapolate" != " " ]; then
    echo "Doing extrapolation..."
    echo $(for v in $to_extrapolate ; do echo $v | awk -F '=' '{print $1}' ; done)
    eval export $to_extrapolate
fi

echo "Starting $@..."
"$@"
