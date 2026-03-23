variable "instance_name" {
  description = "Name tag for the monitoring EC2 instance"
  type        = string
}

variable "instance_ami" {
  description = "AMI ID for the monitoring EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the monitoring EC2 instance"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  nullable    = true
}

variable "subnet_id" {
  description = "Subnet ID where the monitoring instance is deployed"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the monitoring instance security group"
  type        = string
}

variable "admin_ingress_cidr" {
  description = "CIDR allowed to access the monitoring VM"
  type        = string
}

variable "internal_dns_zone_name" {
  description = "Internal DNS zone name used by the environment"
  type        = string
}

variable "web1_private_ip" {
  description = "Private IP address of web instance 1 used by Prometheus scrape"
  type        = string
}

variable "web2_private_ip" {
  description = "Private IP address of web instance 2 used by Prometheus scrape"
  type        = string
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "postgres_exporter_host" {
  description = "PostgreSQL host used by postgres_exporter"
  type        = string
}

variable "postgres_exporter_port" {
  description = "PostgreSQL port used by postgres_exporter"
  type        = number
}

variable "postgres_exporter_database" {
  description = "PostgreSQL database name used by postgres_exporter"
  type        = string
}

variable "postgres_exporter_user" {
  description = "PostgreSQL username used by postgres_exporter"
  type        = string
}

variable "postgres_exporter_password" {
  description = "PostgreSQL password used by postgres_exporter"
  type        = string
  sensitive   = true
}
