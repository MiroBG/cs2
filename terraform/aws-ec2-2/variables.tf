variable "ec2_name" {
  description = "Name tag for EC2 instance"
  type        = string
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instance"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ec2_key_name" {
  description = "EC2 key pair name"
  type        = string
  nullable    = true
}

variable "ec2_subnet_id" {
  description = "Subnet ID for EC2 instance"
  type        = string
}

variable "ec2_security_group_ids" {
  description = "Security groups attached to EC2 instance"
  type        = list(string)
}
