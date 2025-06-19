import json
import logging
import time
import requests
import os # Import the os module to access environment variables
from requests.adapters import HTTPAdapter # Added for retry mechanism
from urllib3.util.retry import Retry # Added for retry mechanism
# Import OpenTelemetry logging API for explicit shutdown
from opentelemetry import _logs # Add this import


# Import OpenTelemetry metrics API for defining custom metrics
from opentelemetry import metrics
from opentelemetry.metrics import Counter, Histogram


# --- Logging Configuration ---
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

handler = logging.StreamHandler()
formatter = logging.Formatter("%(levelname)s: %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

# --- OpenTelemetry Custom Metrics Setup ---
# Retrieve the service name from environment variable,
# defaulting to "my-lambda-app" if not found.
service_name = os.environ.get("OTEL_SERVICE_NAME", "my-lambda-app")
meter = metrics.get_meter(service_name, version="1.0.0")

http_request_count: Counter = meter.create_counter(
    name="http.request.count",
    description="Counts the number of outgoing HTTP requests made by the Lambda.",
    unit="1"
)

http_request_latency_seconds: Histogram = meter.create_histogram(
    name="http.request.latency.seconds",
    description="Measures the latency (duration) of outgoing HTTP requests in seconds.",
    unit="s"
)

# --- Configure Requests Session with Retries ---
# Define the retry strategy
retry_strategy = Retry(
    total=3, # Max 3 retries
    backoff_factor=0.5, # 0.5s, 1s, 2s delays between retries
    status_forcelist=[429, 500, 502, 503, 504], # Retry on these HTTP status codes
    allowed_methods=["HEAD", "GET", "OPTIONS"], # Only retry for safe methods
    raise_on_status=False, # Do not raise for status codes handled by status_forcelist
    connect=3, # Number of retries for connection errors (like ConnectionResetError)
    read=3, # Number of retries for read errors
    respect_retry_after_header=True, # Respect 'Retry-After' header if present
)

# Create an HTTPAdapter with the retry strategy
adapter = HTTPAdapter(max_retries=retry_strategy)

# Create a requests session and mount the adapter for all HTTP and HTTPS requests
http = requests.Session()
http.mount("http://", adapter)
http.mount("https://", adapter)


# --- Lambda Handler Function ---
def lambda_handler(event, context):
    """
    Handles incoming Lambda invocations, makes an outgoing HTTP request,
    and demonstrates OpenTelemetry custom metrics and logging.
    """
    logger.info("Lambda function execution initiated.")
    print("Starting Lambda handler: preparing to make an HTTP request.")

    target_url = "https://www.google.com"

    # --- Custom Metric: Increment Request Count ---
    http_request_count.add(1, {"url": target_url, "function_name": context.function_name})
    logger.debug(f"Custom metric 'http.request.count' incremented for target: {target_url}")
    print(f"Attempting to connect to: {target_url}")

    start_time = time.time()
    response_status_code = None

    try:
        logger.info(f"Executing HTTP GET request to {target_url} with a 10-second timeout.")
        # Perform the HTTP GET request using the session with retries
        response = http.get(target_url, timeout=10)

        # Raise an HTTPError for bad responses (4xx or 5xx status codes) not handled by retries
        response.raise_for_status()

        response_status_code = response.status_code
        end_time = time.time()
        duration = end_time - start_time

        # --- Custom Metric: Record Request Latency ---
        http_request_latency_seconds.record(duration, {
            "url": target_url,
            "status_code": response_status_code,
            "function_name": context.function_name,
            "success": True
        })

        logger.info(f"Successfully received response from {target_url}. Status: {response_status_code}, Duration: {duration:.4f}s")
        logger.debug(f"Custom metric 'http.request.latency.seconds' recorded: {duration:.4f}s for {target_url}")
        print(f"HTTP request to {target_url} completed successfully. Status Code: {response_status_code}.")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully made request to {target_url}',
                'status_code': response_status_code,
                'request_duration_seconds': f"{duration:.4f}"
            })
        }

    except requests.exceptions.Timeout as e:
        end_time = time.time()
        duration = end_time - start_time
        logger.error(f"Request to {target_url} timed out after {duration:.2f}s: {e}", exc_info=True)
        http_request_latency_seconds.record(duration, {
            "url": target_url,
            "error_type": "timeout",
            "function_name": context.function_name,
            "success": False
        })
        print(f"ERROR: Request to {target_url} timed out.")
        return {
            'statusCode': 408,
            'body': json.dumps({'message': f'Request to {target_url} timed out', 'error': str(e)})
        }
    except requests.exceptions.RequestException as e:
        end_time = time.time()
        duration = end_time - start_time
        # This catch will now also handle ConnectionError after retries are exhausted
        logger.error(f"An error occurred during HTTP request to {target_url} after {duration:.2f}s: {e}", exc_info=True)
        http_request_latency_seconds.record(duration, {
            "url": target_url,
            "error_type": "request_exception",
            "function_name": context.function_name,
            "success": False,
            "status_code": response_status_code if response_status_code else "N/A"
        })
        print(f"ERROR: Failed to make HTTP request to {target_url}.")
        return {
            'statusCode': 500,
            'body': json.dumps({'message': f'Failed to make request to {target_url}', 'error': str(e)})
        }
    finally:
        logger.info("Lambda function execution finished.")
        print("Lambda handler completed its run.")
        # Explicitly shut down the logger provider to ensure logs are flushed
        # This is important for short-lived functions like AWS Lambda.
        try:
            _logs.get_logger_provider().shutdown()
            logger.debug("OpenTelemetry LoggerProvider shutdown initiated successfully.")
        except Exception as e:
            logger.error(f"Error during OpenTelemetry LoggerProvider shutdown: {e}", exc_info=True)