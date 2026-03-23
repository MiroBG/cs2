variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "cs1-main-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH into web instances"
  type        = string
  default     = "217.105.46.189/32"
}

variable "ec2_name" {
  description = "Name tag for EC2 instance"
  type        = string
  default     = "web-server"
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-096a4fdbcf530d8e0"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ec2_key_name" {
  description = "EC2 key pair name (optional). Leave null to skip SSH key injection."
  type        = string
  nullable    = true
  default     = null
}

variable "ec2_subnet_id" {
  description = "Subnet ID for EC2 instance"
  type        = string
  default     = "subnet-0aafbb53a6ad6b49d"
}

variable "ec2_security_group_ids" {
  description = "Security groups attached to EC2 instance"
  type        = list(string)
  default     = ["sg-09dd65faddc5f85ad"]
}

variable "ec2_2_name" {
  description = "Name tag for second EC2 instance"
  type        = string
  default     = "web-server-2"
}

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  default     = "cs1-alb"
}

variable "rds_identifier" {
  description = "Identifier of the existing RDS instance"
  type        = string
  default     = "cs1-database"
}

variable "rds_subnet_group_name" {
  description = "Name of the RDS subnet group"
  type        = string
  default     = "cs1-db"
}

variable "rds_monitoring_role_arn" {
  description = "IAM role ARN used for RDS enhanced monitoring (optional)"
  type        = string
  nullable    = true
  default     = null
}

variable "rds_kms_key_id" {
  description = "KMS key ARN used by the RDS instance (optional). Leave null to use the account default key."
  type        = string
  nullable    = true
  default     = null
}

variable "spoke_vpc_name" {
  description = "Name tag for the spoke VPC"
  type        = string
  default     = "cs1-spoke-vpc"
}

variable "spoke_vpc_cidr" {
  description = "CIDR block for the spoke VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "spoke_subnet_name_prefix" {
  description = "Prefix used for spoke subnet Name tags"
  type        = string
  default     = "cs1-spoke"
}

variable "spoke_subnet_public1_a_cidr" {
  description = "CIDR for spoke public subnet in eu-central-1a"
  type        = string
  default     = "10.1.0.0/20"
}

variable "spoke_subnet_public2_b_cidr" {
  description = "CIDR for spoke public subnet in eu-central-1b"
  type        = string
  default     = "10.1.16.0/20"
}

variable "spoke_subnet_private1_a_cidr" {
  description = "CIDR for spoke private subnet in eu-central-1a"
  type        = string
  default     = "10.1.128.0/20"
}

variable "spoke_subnet_private2_b_cidr" {
  description = "CIDR for spoke private subnet in eu-central-1b"
  type        = string
  default     = "10.1.144.0/20"
}

variable "enable_main_nat_gateway" {
  description = "Enable NAT gateway for main VPC private subnet internet egress"
  type        = bool
  default     = true
}

variable "enable_spoke_nat_gateway" {
  description = "Enable NAT gateway for spoke VPC private subnet internet egress"
  type        = bool
  default     = false
}

variable "internal_dns_zone_name" {
  description = "Private Route 53 hosted zone name for internal resolution"
  type        = string
  default     = "cs1.internal"
}

variable "monitoring_instance_name" {
  description = "Name tag for the monitoring EC2 instance"
  type        = string
  default     = "monitoring-server"
}

variable "monitoring_instance_type" {
  description = "Instance type for the monitoring EC2 instance"
  type        = string
  default     = "t3.small"
}

variable "monitoring_key_name" {
  description = "EC2 key pair name for the monitoring instance (optional)"
  type        = string
  nullable    = true
  default     = null
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin1234"
}

variable "postgres_exporter_host" {
  description = "PostgreSQL host used by postgres_exporter"
  type        = string
  default     = "db.cs1.internal"
}

variable "postgres_exporter_port" {
  description = "PostgreSQL port used by postgres_exporter"
  type        = number
  default     = 5432
}

variable "postgres_exporter_database" {
  description = "PostgreSQL database name used by postgres_exporter"
  type        = string
  default     = "postgres"
}

variable "postgres_exporter_user" {
  description = "PostgreSQL username used by postgres_exporter"
  type        = string
  default     = "postgres"
}

variable "postgres_exporter_password" {
  description = "PostgreSQL password used by postgres_exporter"
  type        = string
  sensitive   = true
  default     = "change-me"
}

variable "s3_bucket_name_prefix" {
  description = "Prefix for the CS1 S3 bucket name"
  type        = string
  default     = "cs1-storage"
}

variable "s3_force_destroy" {
  description = "Allow deleting non-empty S3 bucket during terraform destroy"
  type        = bool
  default     = false
}
