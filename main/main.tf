module "aws_vpc_main" {
  source = "../terraform/aws-vpc-main"

  region             = var.region
  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  ssh_ingress_cidr   = var.ssh_ingress_cidr
  enable_nat_gateway = var.enable_main_nat_gateway
}

module "aws_vpc_spoke" {
  source = "../terraform/aws-vpc-main"

  region                 = var.region
  vpc_name               = var.spoke_vpc_name
  vpc_cidr               = var.spoke_vpc_cidr
  azs                    = var.azs
  ssh_ingress_cidr       = var.ssh_ingress_cidr
  subnet_name_prefix     = var.spoke_subnet_name_prefix
  subnet_public1_a_cidr  = var.spoke_subnet_public1_a_cidr
  subnet_public2_b_cidr  = var.spoke_subnet_public2_b_cidr
  subnet_private1_a_cidr = var.spoke_subnet_private1_a_cidr
  subnet_private2_b_cidr = var.spoke_subnet_private2_b_cidr
  enable_nat_gateway     = var.enable_spoke_nat_gateway
}

resource "aws_vpc_peering_connection" "main_to_spoke" {
  vpc_id      = module.aws_vpc_main.vpc_id
  peer_vpc_id = module.aws_vpc_spoke.vpc_id
  auto_accept = true

  tags = {
    Name = "cs1-main-to-spoke"
  }
}

resource "aws_route" "main_public_to_spoke" {
  route_table_id            = module.aws_vpc_main.route_table_public_id
  destination_cidr_block    = var.spoke_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_spoke.id
}

resource "aws_route" "main_private1_to_spoke" {
  route_table_id            = module.aws_vpc_main.route_table_private1_id
  destination_cidr_block    = var.spoke_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_spoke.id
}

resource "aws_route" "main_private2_to_spoke" {
  route_table_id            = module.aws_vpc_main.route_table_private2_id
  destination_cidr_block    = var.spoke_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_spoke.id
}

resource "aws_route" "spoke_public_to_main" {
  route_table_id            = module.aws_vpc_spoke.route_table_public_id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_spoke.id
}

resource "aws_route" "spoke_private1_to_main" {
  route_table_id            = module.aws_vpc_spoke.route_table_private1_id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_spoke.id
}

resource "aws_route" "spoke_private2_to_main" {
  route_table_id            = module.aws_vpc_spoke.route_table_private2_id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main_to_spoke.id
}

locals {
  rds_hostname = split(":", module.aws_rds.db_instance_endpoint)[0]
}

resource "aws_route53_zone" "internal" {
  name = var.internal_dns_zone_name

  vpc {
    vpc_id = module.aws_vpc_main.vpc_id
  }

  vpc {
    vpc_id = module.aws_vpc_spoke.vpc_id
  }

  tags = {
    Name = "cs1-internal-dns"
  }
}

resource "aws_route53_record" "alb_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "app.${var.internal_dns_zone_name}"
  type    = "CNAME"
  ttl     = 300
  records = [module.aws_alb.alb_dns_name]
}

resource "aws_route53_record" "db_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.${var.internal_dns_zone_name}"
  type    = "CNAME"
  ttl     = 300
  records = [local.rds_hostname]
}

resource "aws_route53_record" "web1_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "web1.${var.internal_dns_zone_name}"
  type    = "A"
  ttl     = 300
  records = [module.aws_ec2_1.web_instance_private_ip]
}

resource "aws_route53_record" "web2_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "web2.${var.internal_dns_zone_name}"
  type    = "A"
  ttl     = 300
  records = [module.aws_ec2_2.web_instance_private_ip]
}

module "aws_monitoring" {
  source = "../terraform/aws-monitoring"

  instance_name              = var.monitoring_instance_name
  instance_ami               = var.ec2_ami
  instance_type              = var.monitoring_instance_type
  key_name                   = var.monitoring_key_name
  subnet_id                  = module.aws_vpc_spoke.subnet_public1_a_id
  vpc_id                     = module.aws_vpc_spoke.vpc_id
  admin_ingress_cidr         = var.ssh_ingress_cidr
  internal_dns_zone_name     = var.internal_dns_zone_name
  web1_private_ip            = module.aws_ec2_1.web_instance_private_ip
  web2_private_ip            = module.aws_ec2_2.web_instance_private_ip
  grafana_admin_user         = var.grafana_admin_user
  grafana_admin_password     = var.grafana_admin_password
  postgres_exporter_host     = var.postgres_exporter_host
  postgres_exporter_port     = var.postgres_exporter_port
  postgres_exporter_database = var.postgres_exporter_database
  postgres_exporter_user     = var.postgres_exporter_user
  postgres_exporter_password = var.postgres_exporter_password
}

resource "aws_route53_record" "monitoring_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "monitoring.${var.internal_dns_zone_name}"
  type    = "A"
  ttl     = 300
  records = [module.aws_monitoring.private_ip]
}

resource "aws_security_group_rule" "web_node_exporter_from_monitoring" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  security_group_id        = module.aws_vpc_main.web_security_group_id
  source_security_group_id = module.aws_monitoring.security_group_id
  description              = "Node exporter from monitoring VM"
}

resource "aws_security_group_rule" "db_postgres_from_monitoring" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.aws_vpc_main.db_security_group_id
  source_security_group_id = module.aws_monitoring.security_group_id
  description              = "PostgreSQL from monitoring VM"
}

module "aws_ec2_1" {
  source = "../terraform/aws-ec2-1"

  ec2_name               = var.ec2_name
  ec2_ami                = var.ec2_ami
  ec2_instance_type      = var.ec2_instance_type
  ec2_key_name           = var.ec2_key_name
  ec2_subnet_id          = module.aws_vpc_main.subnet_private2_b_id
  ec2_security_group_ids = [module.aws_vpc_main.web_security_group_id]
}

module "aws_ec2_2" {
  source = "../terraform/aws-ec2-2"

  ec2_name               = var.ec2_2_name
  ec2_ami                = var.ec2_ami
  ec2_instance_type      = var.ec2_instance_type
  ec2_key_name           = var.ec2_key_name
  ec2_subnet_id          = module.aws_vpc_main.subnet_private1_a_id
  ec2_security_group_ids = [module.aws_vpc_main.web_security_group_id]
}

module "aws_alb" {
  source = "../terraform/aws-alb"

  alb_name = var.alb_name
  vpc_id   = module.aws_vpc_main.vpc_id
  public_subnet_ids = [
    module.aws_vpc_main.subnet_public1_a_id,
    module.aws_vpc_main.subnet_public2_b_id,
  ]
  web1_instance_id      = module.aws_ec2_1.web_instance_id
  web2_instance_id      = module.aws_ec2_2.web_instance_id
  web_security_group_id = module.aws_vpc_main.web_security_group_id
}

module "aws_rds" {
  source = "../terraform/aws-rds"

  db_identifier        = var.rds_identifier
  db_subnet_group_name = var.rds_subnet_group_name
  db_subnet_ids = [
    module.aws_vpc_main.subnet_private1_a_id,
    module.aws_vpc_main.subnet_private2_b_id,
  ]
  db_security_group_ids = [module.aws_vpc_main.db_security_group_id]
  monitoring_role_arn   = var.rds_monitoring_role_arn
  kms_key_id            = var.rds_kms_key_id

  # Ensure destroy order: RDS first, VPC last.
  depends_on = [module.aws_vpc_main]
}

module "aws_s3" {
  source = "../terraform/aws-s3"

  bucket_name_prefix = var.s3_bucket_name_prefix
  region             = var.region
  force_destroy      = var.s3_force_destroy
  tags = {
    Project = "cs1"
  }
}
