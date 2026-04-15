variable "enable_openvpn" {
  description = "Create OpenVPN server resources"
  type        = bool
  default     = false
}

variable "instance_name" {
  description = "Name tag for the OpenVPN instance"
  type        = string
  default     = "cs2-openvpn"
}

variable "instance_ami" {
  description = "AMI used for the OpenVPN instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type used for the OpenVPN instance"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Optional EC2 key pair name"
  type        = string
  nullable    = true
  default     = null
}

variable "subnet_id" {
  description = "Public subnet ID where OpenVPN runs"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the OpenVPN security group"
  type        = string
}

variable "openvpn_port" {
  description = "OpenVPN listener port"
  type        = number
  default     = 1194
}

variable "openvpn_protocol" {
  description = "OpenVPN protocol"
  type        = string
  default     = "udp"
}

variable "openvpn_client_cidr" {
  description = "Address pool assigned to VPN clients"
  type        = string
  default     = "10.8.0.0/24"
}

variable "openvpn_ingress_cidrs" {
  description = "CIDR blocks allowed to connect to the OpenVPN port"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_ingress_cidrs" {
  description = "CIDR blocks allowed to SSH into the OpenVPN instance"
  type        = list(string)
  default     = []
}

variable "client_common_name" {
  description = "Common Name used for the generated demo client certificate"
  type        = string
  default     = "cs2-openvpn-client"
}

variable "tags" {
  description = "Tags applied to OpenVPN resources"
  type        = map(string)
  default = {
    Project = "cs2"
  }
}