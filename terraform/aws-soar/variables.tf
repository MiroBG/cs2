variable "name_prefix" {
  description = "Prefix used for SOAR resource names"
  type        = string
  default     = "cs2-soar"
}

variable "event_source" {
  description = "EventBridge source value used to trigger the SOAR rule"
  type        = string
  default     = "cs2.soar"
}

variable "event_rule_name" {
  description = "EventBridge rule name for SOAR alerts"
  type        = string
  default     = "cs2-soar-security-alerts"
}

variable "lambda_function_name" {
  description = "Lambda function name for the SOAR processor"
  type        = string
  default     = "cs2-soar-processor"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda memory allocation in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days for the SOAR Lambda"
  type        = number
  default     = 14
}

variable "incident_table_name" {
  description = "DynamoDB table name used to store incidents"
  type        = string
  default     = "cs2-soar-incidents"
}

variable "alert_topic_name" {
  description = "SNS topic name for SOAR alerts"
  type        = string
  default     = "cs2-soar-alerts"
}

variable "alert_email" {
  description = "Optional email address subscribed to the alert topic"
  type        = string
  nullable    = true
  default     = null
}

variable "enable_scheduled_test_event" {
  description = "Enable a scheduled EventBridge rule that emits a synthetic security alert"
  type        = bool
  default     = false
}

variable "scheduled_test_expression" {
  description = "Schedule expression used by the synthetic SOAR test event rule"
  type        = string
  default     = "rate(30 minutes)"
}

variable "response_tag_key" {
  description = "Tag key applied to target instances by the SOAR Lambda"
  type        = string
  default     = "SOARIncident"
}

variable "response_tag_value_prefix" {
  description = "Prefix used for tag values written by the SOAR Lambda"
  type        = string
  default     = "cs2"
}

variable "enable_instance_shutdown" {
  description = "Allow the Lambda to stop an EC2 instance when a severe event provides a target_instance_id"
  type        = bool
  default     = false
}

variable "shutdown_severity_threshold" {
  description = "Severity threshold required before a target instance can be stopped"
  type        = number
  default     = 8
}

variable "lambda_error_alarm_threshold" {
  description = "Error count threshold for the SOAR Lambda CloudWatch alarm"
  type        = number
  default     = 1
}

variable "lambda_throttle_alarm_threshold" {
  description = "Throttle count threshold for the SOAR Lambda CloudWatch alarm"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags applied to SOAR resources"
  type        = map(string)
  default = {
    Project = "cs2"
  }
}