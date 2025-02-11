### 1 Build the Docker Image of the lambda function:
https://docs.dynatrace.com/docs/ingest-from/opentelemetry/collector
https://github.com/sebas1017/aws-lambda-opentelemetry-docker/blob/master/python_sample_telemetry/README.md

```
docker build -t lambda_function_telemetry
```

```
docker run -v "${PWD}/collector.yaml":/collector.yaml -p 127.0.0.1:4317:4317 -p 127.0.0.1:4318:4318 -p 127.0.0.1:55679:55679 \
    public.ecr.aws/dynatrace/dynatrace-otel-collector:latest --config collector.yaml
```

### 2 Run the AWS Lambda docker container pointing to the collector and send telemetry data

```
docker run -e AWS_LAMBDA_EXEC_WRAPPER='/opt/python/otel-instrument' \
    -e OTEL_EXPORTER_OTLP_ENDPOINT='http://localhost:4318' \
    -e OTEL_EXPORTER_OTLP_PROTOCOL='http/protobuf' \
    -e OTEL_RESOURCE_ATTRIBUTES='service.name=lambda.telemetry.service,service.version=0.1,deployment.environment=dev' \
    -e OTEL_SERVICE_NAME='lambda-telemetry-service' \
    -e OTEL_TRACING='1' \
    --network="host" \
    lambda_function_telemetry
```

### 3 Test the lambda locally
curl --location 'http://localhost:8080/2015-03-31/functions/function/invocations' --header 'Content-Type: application/json' --data-raw '{"body": {}}'