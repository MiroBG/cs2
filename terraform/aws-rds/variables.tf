variable "db_identifier" {
  description = "Identifier of the RDS instance"
  type        = string
}

variable "db_subnet_group_name" {
  description = "Name of the RDS subnet group"
  type        = string
}

variable "db_subnet_ids" {
  description = "Subnet IDs used by the RDS subnet group"
  type        = list(string)
}

variable "db_security_group_ids" {
  description = "Security groups attached to the RDS instance"
  type        = list(string)
}

variable "monitoring_role_arn" {
  description = "IAM role ARN for enhanced monitoring"
  type        = string
  nullable    = true
}

variable "kms_key_id" {
  description = "KMS key ARN used by the RDS instance"
  type        = string
  nullable    = true
}