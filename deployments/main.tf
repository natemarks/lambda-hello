provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 0.13.7"
}

# -----------------------------------------------------------------------------
# Create thr role for the lambda
# -----------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name = var.function_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


# -----------------------------------------------------------------------------
# Attach AWS -managed policies to the  function iam role
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "AWSLambda_ReadOnlyAccess" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "AWSXrayWriteOnlyAccess" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}


# -----------------------------------------------------------------------------
# Create the lambda function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role = aws_iam_role.this.arn
  handler = var.handler_name
  memory_size = var.memory_size
  s3_bucket = var.source_bucket
  s3_key = var.source_key
  #s3_object_version = var.source_object_version
  source_code_hash = filebase64sha256("${var.handler_name}.zip")

  runtime = var.function_runtime
  tracing_config {
    mode = var.tracing_mode
  }

  tags = merge(
  {
    terraform = "true"
    terragrunt = "true"
  },
  var.custom_tags,
  )

  environment {
    variables = merge(
    {
      DEBUG = "FALSE"
      RANDOM_FAILURES = "FALSE"
    },
    var.environment_variables,
    )
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.this,
  ]
}


# -----------------------------------------------------------------------------
# Manage the log retention
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.lambda_log_retention_in_days
}

resource "aws_iam_policy" "lambda_logging" {
  name_prefix        = "${var.function_name}_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}
