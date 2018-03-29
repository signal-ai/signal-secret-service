# signal-secret-service

The intention is for all signal secrets to be held in the [AWS SSM key store](https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#Parameters:sort=Name) this provides encryption, audit and the capacticy for secret rotation.

Day to day writing and reading secrets from SSM is based around the [chamber tool](https://github.com/segmentio/chamber) written by segmentio.

The principle of this tool is to provide a clear route for a developer or and application to access shared secrets within signal.

The chamber wrapper is designed for secret provisioning when executing the entrypoint script in conatiners. It is designed to extrapolate and parse secrets into specific strings needed in execution.

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

An example command for collecting secrets for multiple services and optionaly overriding one of those secrets from service_2 for a specific entry point:

```
$ chamber exec service_1 service_2 -- <entrypoint.sh> OVERRIDE_SERVICE_2_SECRET=123456
```

For more specific documentation for writing more complex operations see the chamber [documentation](https://github.com/segmentio/chamber)

# Container Configuration

[TO BE UPDATED]

# Writing a secret to SSM from terraform:

All secrets are encrypted with the KMS key from core: `data.terraform_remote_state.core.parameter_store_alias_arn`

An example:

```
resource "aws_ssm_parameter" "password" {
  name      = "/${var.name_prefix}-rds-${var.identifier}/${var.identifier}_db_password"
  value     = "${var.db_password}"
  type      = "SecureString"
  key_id    = "${data.terraform_remote_state.core.parameter_store_alias_arn}"
  overwrite = true
}
```

#  More detail

As all secrets are stored in AWS SSM parameter store. At the most basic level with appropriate iam permissions a secret can be retieved with the following command using the aws cli.

```
$ aws ssm get-parameters --names $(db_password_secret) --with-decryption | jq -r '.Parameters[0].Value'
```
