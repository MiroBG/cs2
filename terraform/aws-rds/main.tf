resource "aws_db_subnet_group" "cs1_db_subnets" {
  description = "Created from the RDS Management Console"
  name        = var.db_subnet_group_name
  subnet_ids  = var.db_subnet_ids

  tags = {}
}

resource "aws_db_instance" "cs1_db" {
  allocated_storage                     = 20
  auto_minor_version_upgrade            = true
  availability_zone                     = "eu-central-1b"
  backup_retention_period               = 1
  backup_target                         = "region"
  backup_window                         = "03:28-03:58"
  ca_cert_identifier                    = "rds-ca-rsa2048-g1"
  copy_tags_to_snapshot                 = true
  database_insights_mode                = "standard"
  db_subnet_group_name                  = aws_db_subnet_group.cs1_db_subnets.name
  delete_automated_backups              = true
  deletion_protection                   = false
  enabled_cloudwatch_logs_exports       = []
  engine                                = "postgres"
  engine_lifecycle_support              = "open-source-rds-extended-support-disabled"
  engine_version                        = "17.6"
  iam_database_authentication_enabled   = false
  identifier                            = var.db_identifier
  instance_class                        = "db.t4g.micro"
  kms_key_id                            = var.kms_key_id
  license_model                         = "postgresql-license"
  maintenance_window                    = "wed:22:52-wed:23:22"
  manage_master_user_password           = true
  max_allocated_storage                 = 1000
  monitoring_interval                   = var.monitoring_role_arn != null ? 60 : 0
  monitoring_role_arn                   = var.monitoring_role_arn
  multi_az                              = false
  network_type                          = "IPV4"
  option_group_name                     = "default:postgres-17"
  parameter_group_name                  = "default.postgres17"
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.kms_key_id
  performance_insights_retention_period = 7
  port                                  = 5432
  publicly_accessible                   = false
  skip_final_snapshot                   = true
  storage_encrypted                     = true
  storage_type                          = "gp2"
  username                              = "postgre"
  vpc_security_group_ids                = var.db_security_group_ids

  tags = {}
}