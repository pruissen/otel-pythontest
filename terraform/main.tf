# main.tf
provider "aws" {
  region  = "eu-central-1"
  # Removed profile here, as it's now in SSM
}

# Data sources to get current AWS region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Data source to retrieve the SSM parameter
data "aws_ssm_parameter" "otel_config" {
  name            = "/observability/otel/tst/config"
  with_decryption = true # Set to true if your parameter is a SecureString
}

# Parse the JSON string from the SSM parameter
locals {
  otel_env_vars = jsondecode(data.aws_ssm_parameter.otel_config.value)
}

resource "aws_iam_role" "lambda_role" {
  name = "otel-lambda-sample"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "otel-lambda-sample-policy"
  description = "Policy for Lambda to send telemetry to X-Ray and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permissions required for OpenTelemetry Collector to send data to X-Ray (if used)
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # Permissions for CloudWatch Logs
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # Permissions to read SSM parameters for the Lambda role
        Action = [
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        # Be specific about the resource if possible for least privilege
        Resource = data.aws_ssm_parameter.otel_config.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

## Deploy application package
data "archive_file" "python_lambda_package" {
  type        = "zip"
  # Source directory for your Lambda function code and configuration files
  source_dir  = "../src"
  output_path = "builds/app.zip"
}

resource "aws_lambda_function" "terraform_lambda" {
  function_name    = "otel-lambda-sample" # Explicitly defined function name
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "app.lambda_handler" # Assumes your main function is in src/app.py
  memory_size      = 256 # Increased memory for better performance with OpenTelemetry
  filename         = data.archive_file.python_lambda_package.output_path
  source_code_hash = filesha256(data.archive_file.python_lambda_package.output_path)

  timeout = 30 # Increased timeout to allow for instrumentation overhead and network calls

  environment {
    variables = {
      # Values from SSM Parameter Store
      OTEL_EXPORTER_OTLP_ENDPOINT                 = local.otel_env_vars.OTEL_EXPORTER_OTLP_ENDPOINT
      OTEL_EXPORTER_OTLP_PROTOCOL                 = local.otel_env_vars.OTEL_EXPORTER_OTLP_PROTOCOL
      OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE = local.otel_env_vars.OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE
      DT_API_TOKEN                                = local.otel_env_vars.OTEL_EXPORTER_OTLP_TOKEN # Mapping to the correct key name
      AWS_PROFILE                                 = local.otel_env_vars.AWS_PROFILE # Added AWS_PROFILE from SSM

      # Existing values or values not present in SSM.  These will override the SSM values if there is a conflict.
      OTEL_LOGS_EXPORTER                  = "console, otlp" # Use OTLP exporter for logs
      AWS_LAMBDA_EXEC_WRAPPER            = "/opt/otel-instrument"
      OPENTELEMETRY_COLLECTOR_CONFIG_URI = "file://var/task/collector.yaml"
      OTEL_EXPORTER_OTLP_ENDPOINT_COLLECTOR = "https://yourtenant.live.dynatrace.com/api/v2/otlp" # Collector -> Dynatrace
      OTEL_EXPORTER_OTLP_ENDPOINT        = "http://localhost:4318" # Python SDK -> Local Collector (This one might be overridden by the SSM value if present in SSM and intended for the SDK)
      OTEL_SERVICE_NAME                  = "otel-lambda-test1"
      OTEL_EXPORTER_OTLP_TIMEOUT         = "30000" # 30 seconds
      OTEL_RESOURCE_ATTRIBUTES           = "service.name=otel-lambda-test1,service.version=1.0.0,environment=dev,tenant=observability"
      OTEL_PYTHON_LOG_CORRELATION        = "true" # Enables log correlation with traces
      OTEL_PYTHON_LOG_FORMAT             = "%(msg)s [span_id=%(otelSpanID)s] [trace_id=%(otelTraceID)s]"
      OTEL_PYTHON_LOG_LEVEL              = "debug" # Set Python logger level to debug
      OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED = local.otel_env_vars.OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED # From SSM

      # Environment variables for Collector to dynamically fill Lambda ARN in resource attributes
      TF_AWS_REGION             = data.aws_region.current.name
      TF_AWS_ACCOUNT_ID         = data.aws_caller_identity.current.account_id
      TF_AWS_LAMBDA_FUNCTION_NAME = "otel-lambda-sample"
    }
  }

  layers = [
    # 1. OpenTelemetry Community Python Instrumentation Layer
    # Find the latest stable version for your Python runtime and region from:
    # https://github.com/open-telemetry/opentelemetry-lambda/releases
    "arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-python-0_14_0:1", # Example ARN for Python 3.11


    # 2. OpenTelemetry Community Collector Layer
    # Find the latest stable version for your architecture and region from:
    # https://github.com/open-telemetry/opentelemetry-lambda/releases
    "arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-collector-amd64-0_15_0:1", # Example ARN for amd64 architecture

  ]
  depends_on = [
    data.archive_file.python_lambda_package,
  ]
}