#!/bin/bash
# export DT_OTLP_ENDPOINT="https://yourtenant.live.dynatrace.com/api/v2/otlp"
# export DT_API_TOKEN=""

export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"

export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
export OTEL_RESOURCE_ATTRIBUTES="service.name=testapp2,service.version=1.0.0, environment=dev, tenant=observability"
export OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST=".*"
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE="Delta"

export OTEL_PYTHON_LOG_CORRELATION= "true"
export OTEL_PYTHON_LOG_FORMAT="%(msg)s [span_id=%(span_id)s]"
export OTEL_PYTHON_LOG_LEVEL="debug"
export OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED="true"

opentelemetry-instrument --traces_exporter otlp --metrics_exporter otlp --logs_exporter otlp python3 app.py