# Enhanced security configurations

# DynamoDB encryption at rest
resource "aws_dynamodb_table" "user_feedback_secure" {
  name           = "UserFeedback"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "feedback_id"

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

# API Gateway throttling
resource "aws_api_gateway_usage_plan" "feedback_usage_plan" {
  name = "${var.project_name}-usage-plan"

  api_stages {
    api_id = aws_apigatewayv2_api.feedback_api.id
    stage  = aws_apigatewayv2_stage.feedback_api_stage.name
  }

  throttle_settings {
    rate_limit  = 100
    burst_limit = 200
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    create = aws_lambda_function.create_feedback.function_name
    get    = aws_lambda_function.get_feedback.function_name
    delete = aws_lambda_function.delete_feedback.function_name
  }

  alarm_name          = "${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"

  dimensions = {
    FunctionName = each.value
  }
}

# WAF for API Gateway protection
resource "aws_wafv2_web_acl" "feedback_api_waf" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                 = "RateLimitRule"
      sampled_requests_enabled    = true
    }

    action {
      block {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                 = "${var.project_name}-waf"
    sampled_requests_enabled    = true
  }
}