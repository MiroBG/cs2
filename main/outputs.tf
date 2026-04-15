output "vpc_id" {
  value = module.aws_vpc_main.vpc_id
}

output "spoke_vpc_id" {
  value = module.aws_vpc_spoke.vpc_id
}

output "vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.main_to_spoke.id
}

output "internal_dns_zone_id" {
  value = aws_route53_zone.internal.zone_id
}

output "internal_app_fqdn" {
  value = aws_route53_record.alb_internal.fqdn
}

output "internal_db_fqdn" {
  value = aws_route53_record.db_internal.fqdn
}

output "subnet_private2_b_id" {
  value = module.aws_vpc_main.subnet_private2_b_id
}

output "internet_gateway_id" {
  value = module.aws_vpc_main.internet_gateway_id
}

output "s3_vpc_endpoint_id" {
  value = module.aws_vpc_main.s3_vpc_endpoint_id
}

output "ec2_web_instance_id" {
  value = module.aws_ec2_1.web_instance_id
}

output "ec2_web2_instance_id" {
  value = module.aws_ec2_2.web_instance_id
}

output "alb_dns_name" {
  value = module.aws_alb.alb_dns_name
}

output "alb_arn" {
  value = module.aws_alb.alb_arn
}

output "rds_instance_id" {
  value = module.aws_rds.db_instance_id
}

output "rds_endpoint" {
  value = module.aws_rds.db_instance_endpoint
}

output "rds_subnet_group_name" {
  value = module.aws_rds.db_subnet_group_name
}

output "monitoring_instance_id" {
  value = module.aws_monitoring.instance_id
}

output "monitoring_private_ip" {
  value = module.aws_monitoring.private_ip
}

output "monitoring_public_ip" {
  value = module.aws_monitoring.public_ip
}

output "monitoring_public_dns" {
  value = module.aws_monitoring.public_dns
}

output "monitoring_security_group_id" {
  value = module.aws_monitoring.security_group_id
}

output "s3_bucket_name" {
  value = module.aws_s3.bucket_name
}

output "s3_bucket_arn" {
  value = module.aws_s3.bucket_arn
}

output "soar_alert_topic_arn" {
  value = module.aws_soar.alert_topic_arn
}

output "soar_incident_table_name" {
  value = module.aws_soar.incident_table_name
}

output "soar_lambda_function_name" {
  value = module.aws_soar.lambda_function_name
}

output "soar_event_rule_name" {
  value = module.aws_soar.event_rule_name
}

output "soar_lambda_error_alarm_name" {
  value = module.aws_soar.lambda_error_alarm_name
}

output "soar_lambda_throttle_alarm_name" {
  value = module.aws_soar.lambda_throttle_alarm_name
}

output "soar_scheduled_test_rule_name" {
  value = module.aws_soar.scheduled_test_rule_name
}
