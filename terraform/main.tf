provider "aws" {
  region  = "eu-central-1"
  profile = "YOUR_AWS_PROFILE"
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
  description = "Policy for Lambda to call AWS services with OpenTelemetry"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

### Deploy application-lib layer
resource "null_resource" "install_layer_dependencies" {
  provisioner "local-exec" {
    command = "pip install --no-cache-dir -r ../src/requirements.txt -t builds/layer/python/lib/python3.11/site-packages"
  }
  triggers = {
    trigger = timestamp()
  }
}

data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "builds/layer"
  output_path = "builds/layer.zip"
  depends_on = [
    null_resource.install_layer_dependencies
  ]
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename = "builds/layer.zip"
  source_code_hash = data.archive_file.layer_zip.output_base64sha256
  layer_name = "requests"

  compatible_runtimes = ["python3.11"]
  depends_on = [
    data.archive_file.layer_zip
  ]
}

## Deploy application 
data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_dir  = "../src"
  output_path = "builds/app.zip"
}

resource "aws_lambda_function" "terraform_lambda" {
  function_name    = "otel-lambda-sample"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "app.lambda_handler"
  memory_size      = 128
  filename         = data.archive_file.python_lambda_package.output_path
  source_code_hash = filesha256(data.archive_file.python_lambda_package.output_path)

  # Xray Tracing
  # # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#tracing_config
  # tracing_config {
  #   mode = "Active"
  # }

  timeout = 20
  environment {
    variables = {
      OTEL_TRACES_EXPORTER                                     = "console,otlp"
      OTEL_METRICS_EXPORTER                                    = "console,otlp"
      OTEL_LOGS_EXPORTER                                       = "console,otlp"
      OTEL_EXPORTER_OTLP_PROTOCOL                              = "http/protobuf"
      
      DT_OTLP_ENDPOINT                                         = "https://YOURTENANT/api/v2/otlp"
      DT_API_TOKEN                                             = "YOUR_API_TOKEN"
      AWS_LAMBA_EXEC_WRAPPER                                   = "/opt/otel-instrument"
      OPENTELEMETRY_COLLECTOR_CONFIG_URI                       = "file://var/task/collector.yaml"
      # deprecated OPENTELEMETRY_COLLECTOR_CONFIG_FILE         = "/var/task/collector.yaml"

      OTEL_EXPORTER_OTLP_ENDPOINT                              = "http://localhost:4318"
      OTEL_EXPORTER_OTLP_TIMEOUT                               = 3000
      OTEL_RESOURCE_ATTRIBUTES                                 = "service.name=otel-lambda-sample,service.version=1.0.0, environment=dev, tenant=observability"
      # OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST = ".*"
      # OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE        = "Delta"

      OTEL_PYTHON_LOG_CORRELATION                               = "true"
      OTEL_PYTHON_LOG_FORMAT                                    = "%(msg)s [span_id=%(span_id)s]"
      OTEL_PYTHON_LOG_LEVEL                                     = "debug"
      OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED          = "true"
    }
  }

  layers = [
    # First method ---------------------------
    # ADOT layer collector + autoinstrumentation in one layer
    "arn:aws:lambda:eu-central-1:901920570463:layer:aws-otel-python-amd64-ver-1-29-0:1",
    # See https://github.com/aws-observability/aws-otel-community/tree/master/sample-apps/python-auto-instrumentation-sample-app

    # Second method ---------------------------
    # OTEL layer collector 
    # "arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-collector-amd64-0_12_0:1",
    # OTEL layer autoinstrumentation 
    # https://github.com/open-telemetry/opentelemetry-lambda/tree/main/python/sample-apps/aws-sdk/deploy/wrapper
    # https://github.com/open-telemetry/opentelemetry-lambda/releases
    # "arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-python-0_11_0:1",


    #URL=$(aws lambda get-layer-version-by-arn --arn arn:aws:lambda:eu-central-1:184161586896:layer:opentelemetry-python-0_11_0:1 --query Content.Location --output text)
    #curl $URL -o opentelemetry-python-layer.zip

    # Local layer with pip dependencies such as requests
    aws_lambda_layer_version.lambda_layer.arn
  ]
  depends_on = [
    data.archive_file.python_lambda_package,
    aws_lambda_layer_version.lambda_layer
  ]

}
