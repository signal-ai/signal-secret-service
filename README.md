# signal-secret-service

init.sh is a wrapper for extracting secrets into Docker containers from AWS SSM before the application starts. It uses [chamber](https://github.com/segmentio/chamber) to fetch secrets and supports ENV variable extrapolation and overrides.
It has been designed to work with AWS ECS.

The intention is for all secrets to be held in the [AWS SSM key store](https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#Parameters:sort=Name). It provides encryption, audit and the ability for secret rotation.

## Local Use

For Mac OS X users, you can use brew:
```
$ brew install chamber
```

An example command to write a secret to SSM for a specific service:
```
$ chamber write <service> <key> <value>
```

If `-` is provided as the `<value>` argument, the value will be read from standard
input. You will also need to provide AWS keys or export your profile through AWS_PROFILE ENV variable.

An example command for collecting secrets for multiple services and optionaly overriding one of those secrets from service_2 for a specific entry point:
```
$ chamber exec service_1 service_2 -- <entrypoint.sh> SERVICE_2_SECRET=123456
```

For more specific documentation for writing more complex operations see the chamber [documentation](https://github.com/segmentio/chamber)

## Container Configuration

To install the wrapper into your Docker container, please add the following to your Dockerfile:
```
ADD https://raw.githubusercontent.com/SignalMedia/signal-secret-service/master/init.sh /
RUN chmod +x /init.sh && /init.sh
```

The init.sh script will retrieve chamber's linux 64bit binary into / with curl. curl should be available in most Docker images. For Alpine Linux,
please add curl as a base package with:

```
RUN apk add curl
ADD https://raw.githubusercontent.com/SignalMedia/signal-secret-service/master/init.sh /
RUN chmod +x /init.sh && /init.sh
```

In alternative, you could directly install chamber with Docker with:
```
ADD https://github.com/segmentio/chamber/releases/download/v2.0.0/chamber-v2.0.0-linux-amd64
ADD https://raw.githubusercontent.com/SignalMedia/signal-secret-service/master/init.sh /
RUN chmod +x /init.sh && /init.sh
```

To extract secrets during runtime, you just need to modify your ENTRYPOINT (or CMD if no ENTRYPOINT is used) to run init.sh before calling your app:
```
ENTRYPOINT ["/init.sh", "/myapp"]
```

It will also work if you have multiple arguments in use by your app:
```
ENTRYPOINT ["/init.sh", "python", "-u", "my_app.py"]
```

Both shell and exec forms should work.

init.sh will output information regarding what chamber services were used and what keys were extracted during initialization. Check
stdout (ECS/CloudWatch) for more info.

## Infrastructure config and EC2/ECS policy configuration.

Following chamber's best practices, all secrets are encrypted with the KMS alias parameter_store_key.

An example of writing a secret to SSM from Terraform:

```HCL
resource "aws_ssm_parameter" "password" {
  name      = "my_db_password"
  value     = "some_secret"
  type      = "SecureString"
  key_id    = "${var.parameter_store_alias_arn}"
  overwrite = true
}
```

Where ${var.parameter_store_alias_arn} is a variable pointing to your parameter_store_key KMS alias arn.

Example IAM roles to give an ECS task permissions to read secrets using Terraform:

```HCL
resource "aws_iam_role_policy" "policy-ssm" {
  name = "role-policy-ssm"
  role = "${iam_task_role_id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ssm:getParameters",
        "ssm:DescribeParameters",
        "ssm:GetParametersByPath"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:ssm:eu-west-1:123456123:parameter/*"
    },
    {
      "Action": "kms:Decrypt",
      "Effect": "Allow",
      "Resource": "${aws_kms_key.parameter_store.arn}"
    }
  ]
}
EOF
}
```

Replace "arn:aws:ssm:eu-west-1:123456123:parameter/\*" with specific parameter access you want to give to your ECS task. For more information, please check 
[Controlling Access to Systems Manager Parameters](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html)
${aws_kms_key.parameter_store.arn} is your parameter store key KMS arn.

##  More Detail

As all secrets are stored in AWS SSM parameter store. At the most basic level with appropriate IAM permissions a secret can be retieved with the following command using the AWS cli:

```
$ aws ssm get-parameters --names my_db_password --with-decryption | jq -r '.Parameters[0].Value'
```
