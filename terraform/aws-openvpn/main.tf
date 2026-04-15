terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  openvpn_enabled = var.enable_openvpn
  server_cn       = "${var.instance_name}.internal"
  client_ovpn_config = local.openvpn_enabled ? templatefile("${path.module}/templates/client.ovpn.tftpl", {
    openvpn_protocol = var.openvpn_protocol
    openvpn_port     = var.openvpn_port
    remote_dns       = aws_instance.openvpn[0].public_dns
    ca_cert          = tls_self_signed_cert.ca[0].cert_pem
    client_cert      = tls_locally_signed_cert.client[0].cert_pem
    client_key       = tls_private_key.client[0].private_key_pem
  }) : null
}

resource "tls_private_key" "ca" {
  count     = local.openvpn_enabled ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  count                 = local.openvpn_enabled ? 1 : 0
  private_key_pem       = tls_private_key.ca[0].private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600
  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
    "key_encipherment",
  ]

  subject {
    common_name  = "${var.instance_name}-ca"
    organization = "CS2"
  }
}

resource "tls_private_key" "server" {
  count     = local.openvpn_enabled ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  count           = local.openvpn_enabled ? 1 : 0
  private_key_pem = tls_private_key.server[0].private_key_pem

  subject {
    common_name  = local.server_cn
    organization = "CS2"
  }
}

resource "tls_locally_signed_cert" "server" {
  count                 = local.openvpn_enabled ? 1 : 0
  cert_request_pem      = tls_cert_request.server[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca[0].cert_pem
  validity_period_hours = 87600
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

resource "tls_private_key" "client" {
  count     = local.openvpn_enabled ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  count           = local.openvpn_enabled ? 1 : 0
  private_key_pem = tls_private_key.client[0].private_key_pem

  subject {
    common_name  = var.client_common_name
    organization = "CS2"
  }
}

resource "tls_locally_signed_cert" "client" {
  count                 = local.openvpn_enabled ? 1 : 0
  cert_request_pem      = tls_cert_request.client[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca[0].cert_pem
  validity_period_hours = 87600
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
  ]
}

resource "aws_security_group" "openvpn" {
  count       = local.openvpn_enabled ? 1 : 0
  name        = "${var.instance_name}-sg"
  description = "Security group for OpenVPN server"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.openvpn_ingress_cidrs
    content {
      description = "OpenVPN client ingress"
      from_port   = var.openvpn_port
      to_port     = var.openvpn_port
      protocol    = var.openvpn_protocol
      cidr_blocks = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.ssh_ingress_cidrs
    content {
      description = "SSH admin ingress"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-sg"
  })
}

resource "aws_instance" "openvpn" {
  count                       = local.openvpn_enabled ? 1 : 0
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.openvpn[0].id]
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    if command -v dnf >/dev/null 2>&1; then
      dnf update -y
      dnf install -y openvpn
    elif command -v apt-get >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get install -y openvpn
    fi

    mkdir -p /etc/openvpn/server
    mkdir -p /etc/openvpn/client

    cat > /etc/openvpn/server/ca.crt <<'CA_CERT'
${tls_self_signed_cert.ca[0].cert_pem}
CA_CERT

    cat > /etc/openvpn/server/server.crt <<'SERVER_CERT'
${tls_locally_signed_cert.server[0].cert_pem}
SERVER_CERT

    cat > /etc/openvpn/server/server.key <<'SERVER_KEY'
${tls_private_key.server[0].private_key_pem}
SERVER_KEY

    chmod 600 /etc/openvpn/server/server.key

    cat > /etc/openvpn/server/server.conf <<'SERVER_CONF'
port ${var.openvpn_port}
proto ${var.openvpn_protocol}
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
topology subnet
server ${var.openvpn_client_cidr}
keepalive 10 120
persistent-key
persistent-tun
user nobody
group nobody
verb 3
explicit-exit-notify 1
SERVER_CONF

    sysctl -w net.ipv4.ip_forward=1
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn.conf

    if systemctl list-unit-files | grep -q 'openvpn-server@.service'; then
      systemctl enable --now openvpn-server@server
    elif systemctl list-unit-files | grep -q 'openvpn@.service'; then
      systemctl enable --now openvpn@server
    fi
  EOF

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}