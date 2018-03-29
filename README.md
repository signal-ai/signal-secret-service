# signal-secret-service

This service is based around the [chamber tool](https://github.com/segmentio/chamber) written by segmentio.

The principle of this tool is to provide a clear route for a developer or and application to access shared secrets within signal.

The chamber tool is a wrapper that performs this action for multiple secrets for each service required.

# Local Developer Installation

```
$ brew install chamber
```

An example command to write a secret to ssm for a specific service:
```
$ chamber write <service> <key> <value>
```

If `-` is provided as the value argument, the value will be read from standard
input.

An example useful command for collecting secrets for multiple services and optionaly overriding one of those secrets from service_2 for a specific entry point:

```
$ chamber exec service_1 service_2 -- <entrypoint.sh> OVERRIDE_SERVICE_2_SECRET=123456
```

For more specific documentation for writing more complex operations see the chamber [documentation](https://github.com/segmentio/chamber)

# Container Entrypoint Configuration

[TO BE UPDATED]

#  More detail

All secrets are stored in AWS SSM parameter store. At the most basic level with appropriate iam permissions a secret can be retieved with the following command using the aws cli.

```
$ aws ssm get-parameters --names $(db_password_secret) --with-decryption | jq -r '.Parameters[0].Value'
```
