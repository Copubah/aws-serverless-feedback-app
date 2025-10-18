terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# DynamoDB Table
resource "aws_dynamodb_table" "user_feedback" {
  name         = "UserFeedback"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "feedback_id"

  attribute {
    name = "feedback_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-feedback-table"
    Environment = var.environment
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

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

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.user_feedback.arn
      }
    ]
  })
}

# Lambda function for creating feedback
data "archive_file" "create_feedback_zip" {
  type        = "zip"
  source_file = "../backend/create_feedback.py"
  output_path = "create_feedback.zip"
}

resource "aws_lambda_function" "create_feedback" {
  filename         = "create_feedback.zip"
  function_name    = "${var.project_name}-create-feedback"
  role             = aws_iam_role.lambda_role.arn
  handler          = "create_feedback.lambda_handler"
  source_code_hash = data.archive_file.create_feedback_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.create_feedback_logs,
  ]
}

# Lambda function for getting feedback
data "archive_file" "get_feedback_zip" {
  type        = "zip"
  source_file = "../backend/get_feedback.py"
  output_path = "get_feedback.zip"
}

resource "aws_lambda_function" "get_feedback" {
  filename         = "get_feedback.zip"
  function_name    = "${var.project_name}-get-feedback"
  role             = aws_iam_role.lambda_role.arn
  handler          = "get_feedback.lambda_handler"
  source_code_hash = data.archive_file.get_feedback_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.get_feedback_logs,
  ]
}

# Lambda function for deleting feedback
data "archive_file" "delete_feedback_zip" {
  type        = "zip"
  source_file = "../backend/delete_feedback.py"
  output_path = "delete_feedback.zip"
}

resource "aws_lambda_function" "delete_feedback" {
  filename         = "delete_feedback.zip"
  function_name    = "${var.project_name}-delete-feedback"
  role             = aws_iam_role.lambda_role.arn
  handler          = "delete_feedback.lambda_handler"
  source_code_hash = data.archive_file.delete_feedback_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.delete_feedback_logs,
  ]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "create_feedback_logs" {
  name              = "/aws/lambda/${var.project_name}-create-feedback"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "get_feedback_logs" {
  name              = "/aws/lambda/${var.project_name}-get-feedback"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "delete_feedback_logs" {
  name              = "/aws/lambda/${var.project_name}-delete-feedback"
  retention_in_days = 14
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "feedback_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type"]
    allow_methods     = ["*"]
    allow_origins     = ["*"]
    expose_headers    = ["date", "keep-alive"]
    max_age           = 86400
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "feedback_api_stage" {
  api_id      = aws_apigatewayv2_api.feedback_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda integrations
resource "aws_apigatewayv2_integration" "create_feedback_integration" {
  api_id           = aws_apigatewayv2_api.feedback_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.create_feedback.invoke_arn
}

resource "aws_apigatewayv2_integration" "get_feedback_integration" {
  api_id           = aws_apigatewayv2_api.feedback_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.get_feedback.invoke_arn
}

resource "aws_apigatewayv2_integration" "delete_feedback_integration" {
  api_id           = aws_apigatewayv2_api.feedback_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.delete_feedback.invoke_arn
}

# API Routes
resource "aws_apigatewayv2_route" "create_feedback_route" {
  api_id    = aws_apigatewayv2_api.feedback_api.id
  route_key = "POST /feedback"
  target    = "integrations/${aws_apigatewayv2_integration.create_feedback_integration.id}"
}

resource "aws_apigatewayv2_route" "get_feedback_route" {
  api_id    = aws_apigatewayv2_api.feedback_api.id
  route_key = "GET /feedback"
  target    = "integrations/${aws_apigatewayv2_integration.get_feedback_integration.id}"
}

resource "aws_apigatewayv2_route" "delete_feedback_route" {
  api_id    = aws_apigatewayv2_api.feedback_api.id
  route_key = "DELETE /feedback/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.delete_feedback_integration.id}"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "create_feedback_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_feedback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.feedback_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_feedback_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_feedback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.feedback_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "delete_feedback_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_feedback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.feedback_api.execution_arn}/*/*"
}

# S3 Bucket for static website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.project_name}-website-${random_string.bucket_suffix.result}"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website_pab" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket     = aws_s3_bucket.website_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.website_pab]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

# Upload frontend files to S3
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  source       = "../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("../frontend/index.html")
}

resource "aws_s3_object" "script_js" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "script.js"
  source       = "../frontend/script.js"
  content_type = "application/javascript"
  etag         = filemd5("../frontend/script.js")
}