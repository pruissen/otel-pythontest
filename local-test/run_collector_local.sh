#!/bin/bash

export DT_OTLP_ENDPOINT="https://yourtenant.live.dynatrace.com/api/v2/otlp"
export DT_API_TOKEN="yourtoken"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"

export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318/"
export OTEL_RESOURCE_ATTRIBUTES="service.name=otel-lambda-test1,service.version=1.0.0, environment=dev, tenant=observability"
export OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST=".*"
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE="Delta"

export OTEL_PYTHON_LOG_CORRELATION="true"
export OTEL_PYTHON_LOG_FORMAT="%(msg)s [span_id=%(span_id)s]"
export OTEL_PYTHON_LOG_LEVEL="debug"
export OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED="true"

docker run -v "${PWD}/collector.yaml":/collector.yaml -p 127.0.0.1:4317:4317 -p 127.0.0.1:4318:4318 -p 127.0.0.1:55679:55679 \
    otel/opentelemetry-collector --config collector.yaml 2>&1 | tee collector-output.txt