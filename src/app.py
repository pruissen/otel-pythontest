import os
import requests
import logging

# OpenTelemetry SDK imports for logs
from opentelemetry._logs import get_logger_provider, set_logger_provider # ADDED get_logger_provider
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor, SimpleLogRecordProcessor, ConsoleLogExporter

from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter

# OpenTelemetry imports for traces and metrics
from opentelemetry import trace, metrics

# --- START OpenTelemetry Logging Configuration ---
print("--- [DIAGNOSTIC] Setting up OpenTelemetry Logging in app.py (attempting to use existing provider) ---")

# Try to get the LoggerProvider that might have already been set by the Lambda Layer.
# If not found, fall back to creating a new one (though unlikely with the wrapper).
try:
    otel_logger_provider = get_logger_provider()
    print("--- [DIAGNOSTIC] Found existing LoggerProvider from layer. ---")
except RuntimeError:
    # This block should ideally not be hit if the otel-instrument wrapper runs first.
    print("--- [DIAGNOSTIC] No existing LoggerProvider found. Creating a new one. ---")
    otel_logger_provider = LoggerProvider()
    set_logger_provider(otel_logger_provider)


# OTLP log exporter (sends logs to the OTEL collector or Dynatrace)
#otlp_log_exporter = OTLPLogExporter()

# Batch processor is preferred for performance
#otel_logger_provider.add_log_record_processor(BatchLogRecordProcessor(otlp_log_exporter))

# # Also export logs to console for debugging (optional, remove later if only OTLP is desired)
# console_exporter = ConsoleLogExporter()
# otel_logger_provider.add_log_record_processor(SimpleLogRecordProcessor(console_exporter))

console_exporter = ConsoleLogExporter()
otel_logger_provider.add_log_record_processor(BatchLogRecordProcessor(console_exporter))

# Attach OTEL logging to Python logging
# Check if LoggingHandler is already attached to avoid duplicates on warm starts.
# Duplicates can lead to logs being processed multiple times.
if not any(isinstance(h, LoggingHandler) for h in logging.getLogger().handlers):
    otel_logging_handler = LoggingHandler(logger_provider=otel_logger_provider)
    logging.getLogger().addHandler(otel_logging_handler)
    print("--- [DIAGNOSTIC] OpenTelemetry LoggingHandler added. ---")
else:
    print("--- [DIAGNOSTIC] OpenTelemetry LoggingHandler already present. Skipping re-add. ---")


# Set Python root log level from env (OTEL_PYTHON_LOG_LEVEL)
# This controls which messages Python's logging module will process and pass on.
log_level = os.environ.get("OTEL_PYTHON_LOG_LEVEL", "INFO").upper()
logging.getLogger().setLevel(getattr(logging, log_level, logging.INFO))
print(f"--- [DIAGNOSTIC] Python root logger level set to: {logging.getLogger().level} ({log_level}) ---")

# --- END OpenTelemetry Logging Configuration ---

# Initialize Tracer and Meter
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
logger = logging.getLogger(__name__) # Ensure this is initialized AFTER OTel logging setup


# Custom metrics
request_count = meter.create_counter(
    "http_request_count",
    description="Counts the number of HTTP requests made",
    unit="1"
)

http_latency = meter.create_histogram(
    "http_request_latency_seconds",
    description="Measures the latency of HTTP requests",
    unit="s"
)

def lambda_handler(event, context):
    logger.info("Lambda invocation started.")

    target_url = "https://www.google.com"

    with tracer.start_as_current_span("lambda_execution") as lambda_span:
        lambda_span.set_attribute("lambda.function_name", context.function_name)
        lambda_span.set_attribute("lambda.request_id", context.aws_request_id)

        try:
            with tracer.start_as_current_span("call_google_com") as http_span:
                http_span.set_attribute("http.method", "GET")
                http_span.set_attribute("http.url", target_url)

                logger.info(f"Making request to {target_url}")
                response = requests.get(target_url, timeout=5)

                http_span.set_attribute("http.status_code", response.status_code)
                logger.info(f"Request completed with status: {response.status_code}")

                request_count.add(1, {"url": target_url, "status_code": response.status_code})
                http_latency.record(response.elapsed.total_seconds(), {"url": target_url})

                if response.status_code == 200:
                    logger.info("Successfully fetched content from Google.")
                    http_span.set_status(trace.StatusCode.OK)
                else:
                    logger.warning(f"Non-200 status code received: {response.status_code}")
                    http_span.record_exception(Exception(f"HTTP request failed with status: {response.status_code}"))
                    http_span.set_status(trace.StatusCode.ERROR, description=f"HTTP Error {response.status_code}")

        except requests.exceptions.RequestException as e:
            logger.error(f"Request error: {e}")
            lambda_span.record_exception(e)
            lambda_span.set_status(trace.StatusCode.ERROR, description=str(e))
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            lambda_span.record_exception(e)
            lambda_span.set_status(trace.StatusCode.ERROR, description=str(e))

    logger.info("Lambda invocation finished.")
    return {
        'statusCode': 200,
        'body': 'Lambda executed successfully with OpenTelemetry data.'
    }