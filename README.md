# obs-otel-adot
## Disclaimer: this is for testing
Setup: use [![Built with Devbox](https://www.jetify.com/img/devbox/shield_galaxy.svg)](https://www.jetify.com/devbox/docs/contributor-quickstart/)

With ADOT, you have: “the ability to send observability data to multiple different backends without having to re-instrument your code.

Backends can be X-Ray, Dynatrace or others

## Opentelemetry in the Dynatrace GUI
![Alt text](docs/images/result.png?raw=true "Adot Dynatrace")

## Design
![Alt text](docs/images/adot-layer.png?raw=true "Adot Dynatrace")

## How to deploy with terraform to lambda:
This is terraform but can be changed to CDK, SAM or whatever
```bash
# Clone the repo, set your user profile and use the Makefile to deploy the lambda
(.venv) user:~/otel-pythontest$ git clone git@github.com:pruissen/otel-pythontest.git
(.venv) user:~/otel-pythontest$  cd terraform
(.venv) user:~/otel-pythontest/terraform$ export AWS_PROFILE="yourprofile"
(.venv) user:~/otel-pythontest/terraform$ aws sts get-caller-identity
{
    "UserId": "userid",
    "Account": "accountid",
    "Arn": "arn:aws:sts::accountid:assumed-role/AWSReservedSSO_useraccountname"
}
(.venv) user:~/otel-pythontest/terraform$ $ make clean
(.venv) user:~/otel-pythontest/terraform$ $ make deploy
```
## AWS Parameter store
The terraform config uses config from the AWS parameter store in the following format:
```bash
key name: /observability/otel/tst/config
description: Opentelemetry demo for AWS Lambda/EKS with Dynatrace backend
```
```bash
{
"OTEL_EXPORTER_OTLP_ENDPOINT":"https://yourtenant.live.dynatrace.com/api/v2/otlp",
"OTEL_EXPORTER_OTLP_TOKEN":"yourtoken.yourkey",
"OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE":"delta",
"OTEL_EXPORTER_OTLP_PROTOCOL":"http/protobuf",
"OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED":"true",
"AWS_PROFILE":"yourprofile-optionally"
}
```


#### Opentelemetry layers: an alternative for adot
```bash
    # 1. OpenTelemetry Community Python Instrumentation Layer
    # Find the latest stable version for your Python runtime and region from:
    # https://github.com/open-telemetry/opentelemetry-lambda/releases
    "arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-python-0_14_0:1", # Example ARN for Python 3.11
    # 2. OpenTelemetry Community Collector Layer
    # Find the latest stable version for your architecture and region from:
    # https://github.com/open-telemetry/opentelemetry-lambda/releases
    "arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-collector-amd64-0_15_0:1", # Example ARN for amd64 architecture
```

#### Links
- https://aws.amazon.com/blogs/opensource/auto-instrumenting-a-python-application-with-an-aws-distro-for-opentelemetry-lambda-layer/
- https://catalog.workshops.aws/observability/en-US/aws-managed-oss/adot/lambda-tracing
- https://github.com/aws-observability/aws-otel-lambda/tree/main
- https://github.com/open-telemetry/opentelemetry-lambda/blob/main/python/src/otel/Makefile
- https://xebia.com/blog/automate-lambda-dependencies-with-terraform/
- https://github.com/open-telemetry/opentelemetry-lambda/blob/main/python/README.md
- https://github.com/open-telemetry/opentelemetry-lambda/blob/main/python/sample-apps/aws-sdk/deploy/wrapper/main.tf
- https://jessitron.com/2021/08/11/run-an-opentelemetry-collector-locally-in-docker/

``` Testing
(.venv) (devbox) $ opentelemetry-bootstrap
opentelemetry-instrumentation-asyncio==0.50b0
opentelemetry-instrumentation-dbapi==0.50b0
opentelemetry-instrumentation-logging==0.50b0
opentelemetry-instrumentation-sqlite3==0.50b0
opentelemetry-instrumentation-threading==0.50b0
opentelemetry-instrumentation-urllib==0.50b0
opentelemetry-instrumentation-wsgi==0.50b0
opentelemetry-instrumentation-boto==0.50b0
opentelemetry-instrumentation-boto3sqs==0.50b0
opentelemetry-instrumentation-botocore==0.50b0
opentelemetry-instrumentation-requests==0.50b0
opentelemetry-instrumentation-urllib3==0.50b0
```