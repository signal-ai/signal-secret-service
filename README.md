# signal-secret-service

This service is based around the [chamber tool](https://github.com/segmentio/chamber) written by segmentio.

The principle of this tool is to provide a clear route for a developer or and application to access shared secrets within signal.

The chamber tool is a wrapper that performs this action for multiple secrets for each service required.

# Local Developer Installation

```
$ brew install chamber
```

For more specific documentation for writing secrets/reading specific secrets see the chamber [documentation](https://github.com/segmentio/chamber)

Specific useful command for collecting secrets for multiple services and optionaly overriding one of those secrets from service_2 for a specific entry point:

```
$ chamber exec service_1 service_2 -- <entrypoint.sh> OVERRIDE_SERVICE_2_SECRET=123456
```

# Container Entrypoint Configuration

[TO BE UPDATED]

#  More detail

All secrets are stored in AWS SSM parameter store. At the most basic level with appropriate iam permissions a secret can be retieved with the following command using the aws cli.

```
$ aws ssm get-parameters --names $(db_password_secret) --with-decryption | jq -r '.Parameters[0].Value'
```
