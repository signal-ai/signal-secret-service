# signal-secret-service

`init.sh` is a wrapper for extracting secrets into Docker containers from AWS SSM before the application starts. It uses [chamber](https://github.com/segmentio/chamber) to fetch secrets and supports ENV variable extrapolation and overrides.
It has been designed to work with AWS ECS.

The intention is for all secrets to be held in the [AWS SSM key store](https://eu-west-1.console.aws.amazon.com/ec2/v2/home?region=eu-west-1#Parameters:sort=Name). AWS SSM provides encryption, audit and the ability for secret rotation.

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
input. You will also need to provide AWS keys or export your profile through `AWS_PROFILE` ENV variable.

An example command for collecting secrets for multiple services and optionaly overriding one of those secrets from service_2 for a specific entry point:
```
$ chamber exec service_1 service_2 -- <entrypoint.sh> SERVICE_2_SECRET=123456
```

For more specific documentation for writing more complex operations see the chamber [documentation](https://github.com/segmentio/chamber).

## Container Configuration

### Building your container with `init.sh`

To install the `init.sh` wrapper into your Docker container, please add the following to your Dockerfile:
```
ADD https://raw.githubusercontent.com/SignalMedia/signal-secret-service/master/init.sh /
RUN chmod +x /init.sh && /init.sh
```

The `init.sh` wrapper installs chamber's linux 64bit binary into / with `curl`. `curl` should be available in most Docker images. For Alpine Linux,
this package will be automatically installed. For other minimal Linux images, please add it before calling `init.sh`.

In alternative, you could directly install chamber with Docker:
```
ADD https://github.com/segmentio/chamber/releases/download/v2.0.0/chamber-v2.0.0-linux-amd64 /chamber
ADD https://raw.githubusercontent.com/SignalMedia/signal-secret-service/master/init.sh /
RUN chmod +x /init.sh && chmod +x /chamber
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

`init.sh` will output information regarding what chamber services were used and what keys were extracted during initialization. Check
stdout (ECS/CloudWatch) for more info.

### ECS Task definition

When deploying your application, you will need to pass the services that you want chamber to decrypt secrets from. You can do this by setting the
ENV variable `SECRET_SERVICES`. Example:

`SECRET_SERVICES=prod-my-app prod-my-db`

This will tell `init.sh` to decrypt secrets for services prod-my-app and prod-my-db using `chamber`. If you want to keep a reference of secret ENV variables
within your app, we can set the value as "SECRET", although there is no need to do that for chamber to extract secrets. Example JSON for ECS task definition:

```JSON
{
  "taskDefinition": {
    "family": "prod-my-app",
    "volumes": [
    ],
    "containerDefinitions": [
      {
        "mountPoints": [],
        "environment": [
          {"name": "ADMIN_PASSWORD", "value": "SECRET"},
          {"name": "API_TOKEN", "value": "SECRET"},
          {"name": "SOME_ENV", "value": "notasecret"},
          {"name": "DB_PASSWORD", "value": "SECRET"},
          {"name": "SECRET_SERVICES", "value": "prod-my-app prod-my-db"}
        ],
        "image": "repo.com/account/prod-my-app",
        "portMappings": [
          {"containerPort": 8000, "hostPort": 8000}
        ],
        "essential": true,
        "cpu": 512,
        "volumesFrom": [],
        "memory": 200,
        "logConfiguration": {
          "options": {
            "awslogs-group": "prod-my-app",
            "awslogs-region": "eu-west-1"
          },
          "logDriver": "awslogs"
        },
        "name": "application"
      }
    ]
  }
}
```

Both `ADMIN_PASSWORD` and `API_TOKEN` are stored under prod-my-app service while `DB_PASSWORD` is stored under prod-my-db (via Terraform). To
get a list of all ENV variables stored for a given service, please do locally:

```
chamber exec service -- env
```

ENV variable extrapolation is supported. For example, if you want to use the value of DB_PASSWORD to set DB_URL, you can:

```
{"name": "DB_URL", "value": "postgres://rdsuser:$DB_PASSWORD@my-db-instance/db_name"},
```

ENV variable secrets can be overwritten. For example, if we use a different API_TOKEN locally or if we are using a local DB for which we will
use docker-compose, we can set:

```
API_TOKEN="123123123"
DB_PASSWORD="local_secret"
```

`init.sh` will always call the override of any secret if original value is not "SECRET".

## Terraform and EC2/ECS policy configuration.

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
  role = "${aws_iam_role.task_role.id}""
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

Replace `arn:aws:ssm:eu-west-1:123456123:parameter/*` with specific parameter access you want to give to your ECS task. For more information, please check 
[Controlling Access to Systems Manager Parameters](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html)
`${aws_kms_key.parameter_store.arn}` is your parameter store key KMS arn.

## Troubleshooting without chamber

As all secrets are stored in AWS SSM parameter store. At the most basic level with appropriate IAM permissions a secret can be retieved with the following command using the AWS cli:

```
$ aws ssm get-parameters-by-path --path /service/secret_key --with-decryption | jq -r '.Parameters[0].Value'
```
