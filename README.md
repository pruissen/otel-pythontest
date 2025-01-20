# obs-otel-adot
## Disclaimer: this is for testing
Setup: use [![Built with Devbox](https://www.jetify.com/img/devbox/shield_galaxy.svg)](https://www.jetify.com/devbox/docs/contributor-quickstart/)

With ADOT, you have: “the ability to send observability data to multiple different backends without having to re-instrument your code.

Backends can be X-Ray, Dynatrace or others

![Alt text](docs/images/adot-layer.png?raw=true "Adot Dynatrace")

## How to deploy with terraform to lambda:
This is terraform but can be chnaged to CDK, SAM or whatever
```bash
cd terraform
make deploy
```
## How to deploy locally:
```bash
src/run_collector_local.sh
src/run.sh
```

## Env variables
These variables can be used for your app
```bash
"OTEL_SERVICE_NAME": "otel-sample1",
"OTEL_SERVICE_VERSION": "1.0.0",
"OTEL_TENANT_NAME": "obs",
"OTEL_RESOURCE_ATTRIBUTES": "service.name=otel-sample1,service.version=1.0.0",
"OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST":".*",
```
These variables can be used if the collector is not present. Otherwise 
```bash
"OTEL_EXPORTER_OTLP_ENDPOINT": "https://yourtenant.live.dynatrace.com/api/v2/otlp"
"OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE": "delta",
"OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
"OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED": "true",
"OTEL_EXPORTER_OTLP_TIMEOUT":"2000"
"OTEL_EXPORTER_OTLP_TOKEN":"dt0c01.yourtoken"
```

#### Adot container images 
```bash
public.ecr.aws/aws-observability/adot-autoinstrumentation-python:v0.8.0
public.ecr.aws/aws-observability/aws-otel-collector:v0.41.2 
```

#### Opentelemetry layers: an alternative for adot
```bash
arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-collector-amd64-0_12_0:1
arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-python-0_11_0:1
```
#### Adot layer combines collector and autoinstrumentation
```bash
arn:aws:lambda:eu-central-1:901920570463:layer:aws-otel-python-amd64-ver-1-29-0:1
```
- Contains OpenTelemetry Python v1.29.0
- Contains ADOT Collector v0.42.0


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
(.venv) (devbox) [al8049@p3561 src (⎈|pax1-tst:demo-cdit-kafka-connector-tst)]$ opentelemetry-bootstrap
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