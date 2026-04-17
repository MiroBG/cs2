output "alert_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "incident_table_name" {
  value = aws_dynamodb_table.incidents.name
}

output "lambda_function_name" {
  value = aws_lambda_function.processor.function_name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.security_alerts.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "lambda_error_alarm_name" {
  value = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
}

output "lambda_throttle_alarm_name" {
  value = aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name
}

output "scheduled_test_rule_name" {
  value = var.enable_scheduled_test_event ? aws_cloudwatch_event_rule.scheduled_test[0].name : null
}

output "dashboard_name" {
  value = var.enable_dashboard ? aws_cloudwatch_dashboard.soar[0].dashboard_name : null
}