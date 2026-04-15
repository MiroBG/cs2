terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

locals {
  lambda_source_file  = "${path.module}/lambda/handler.py"
  lambda_package_path = "${path.module}/build/${var.lambda_function_name}.zip"
  lambda_assume_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = local.lambda_source_file
  output_path = local.lambda_package_path
}

resource "aws_sns_topic" "alerts" {
  name = var.alert_topic_name

  tags = merge(var.tags, {
    Name = var.alert_topic_name
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == null ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_dynamodb_table" "incidents" {
  name         = var.incident_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"

  attribute {
    name = "incident_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = var.incident_table_name
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.lambda_function_name}-logs"
  })
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-lambda-role"
  assume_role_policy = local.lambda_assume_policy

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lambda-role"
  })
}

resource "aws_iam_role_policy" "lambda_inline" {
  name = "${var.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

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
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.incidents.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:CreateTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "processor" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ALERT_TOPIC_ARN             = aws_sns_topic.alerts.arn
      INCIDENT_TABLE_NAME         = aws_dynamodb_table.incidents.name
      ENABLE_INSTANCE_SHUTDOWN    = tostring(var.enable_instance_shutdown)
      SHUTDOWN_SEVERITY_THRESHOLD = tostring(var.shutdown_severity_threshold)
      RESPONSE_TAG_KEY            = var.response_tag_key
      RESPONSE_TAG_VALUE_PREFIX   = var.response_tag_value_prefix
      METRIC_NAMESPACE            = "CS2/SOAR"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = merge(var.tags, {
    Name = var.lambda_function_name
  })
}

resource "aws_cloudwatch_event_rule" "security_alerts" {
  name        = var.event_rule_name
  description = "Trigger the SOAR Lambda for CS2 security alerts"

  event_pattern = jsonencode({
    source        = [var.event_source]
    "detail-type" = ["security-alert"]
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.security_alerts.name
  target_id = "soar-processor"
  arn       = aws_lambda_function.processor.arn
}

resource "aws_cloudwatch_event_rule" "scheduled_test" {
  count               = var.enable_scheduled_test_event ? 1 : 0
  name                = "${var.event_rule_name}-scheduled-test"
  description         = "Synthetic security alert generator for SOAR testing"
  schedule_expression = var.scheduled_test_expression
}

resource "aws_cloudwatch_event_target" "scheduled_test_lambda" {
  count     = var.enable_scheduled_test_event ? 1 : 0
  rule      = aws_cloudwatch_event_rule.scheduled_test[0].name
  target_id = "soar-scheduled-test"
  arn       = aws_lambda_function.processor.arn
  input = jsonencode({
    source        = var.event_source
    "detail-type" = "security-alert"
    detail = {
      severity    = 5
      description = "Synthetic CS2 SOAR scheduled test event"
    }
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_alerts.arn
}

resource "aws_lambda_permission" "allow_scheduled_test_eventbridge" {
  count         = var.enable_scheduled_test_event ? 1 : 0
  statement_id  = "AllowExecutionFromScheduledEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_test[0].arn
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.lambda_function_name}-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = var.lambda_error_alarm_threshold
  alarm_description   = "SOAR Lambda error alarm"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.lambda_function_name}-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = var.lambda_throttle_alarm_threshold
  alarm_description   = "SOAR Lambda throttle alarm"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }
}