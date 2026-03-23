resource "aws_security_group" "monitoring" {
  name        = "MonitoringSecurity"
  description = "Access controls for the monitoring VM"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cs1-monitoring-sg"
  }
}

locals {
  admin_ingress_cidrs = [for cidr in split(",", var.admin_ingress_cidr) : trimspace(cidr) if trimspace(cidr) != ""]
}

resource "aws_security_group_rule" "ssh_from_admin" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.monitoring.id
  cidr_blocks       = local.admin_ingress_cidrs
  description       = "SSH from admin CIDR"
}

resource "aws_security_group_rule" "grafana_from_admin" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  security_group_id = aws_security_group.monitoring.id
  cidr_blocks       = local.admin_ingress_cidrs
  description       = "Grafana from admin CIDR"
}

resource "aws_instance" "monitoring" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  associate_public_ip_address = false
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    if command -v dnf >/dev/null 2>&1; then
      dnf update -y
      dnf install -y docker git
      systemctl enable --now docker
      mkdir -p /usr/local/lib/docker/cli-plugins
      curl -SL https://github.com/docker/compose/releases/download/v2.35.1/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
      chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    elif command -v apt-get >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get install -y docker.io docker-compose-plugin git curl
      systemctl enable --now docker
    fi

    for candidate in ec2-user ubuntu admin; do
      if id "$candidate" >/dev/null 2>&1; then
        usermod -aG docker "$candidate"
      fi
    done

    mkdir -p /opt/monitoring/prometheus
    mkdir -p /opt/monitoring/grafana/provisioning/datasources
    mkdir -p /opt/monitoring/grafana/provisioning/dashboards
    mkdir -p /opt/monitoring/grafana/dashboards

    cat > /opt/monitoring/docker-compose.yml <<'COMPOSE'
    services:
      prometheus:
        image: prom/prometheus:latest
        container_name: prometheus
        restart: unless-stopped
        ports:
          - "9090:9090"
        volumes:
          - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
          - prometheus_data:/prometheus

      grafana:
        image: grafana/grafana:latest
        container_name: grafana
        restart: unless-stopped
        ports:
          - "3000:3000"
        environment:
          GF_SECURITY_ADMIN_USER: ${var.grafana_admin_user}
          GF_SECURITY_ADMIN_PASSWORD: ${var.grafana_admin_password}
        volumes:
          - grafana_data:/var/lib/grafana
          - ./grafana/provisioning:/etc/grafana/provisioning:ro
          - ./grafana/dashboards:/var/lib/grafana/dashboards:ro

      postgres-exporter:
        image: prometheuscommunity/postgres-exporter:latest
        container_name: postgres-exporter
        restart: unless-stopped
        ports:
          - "9187:9187"
        environment:
          DATA_SOURCE_NAME: "postgresql://${var.postgres_exporter_user}:${var.postgres_exporter_password}@${var.postgres_exporter_host}:${var.postgres_exporter_port}/${var.postgres_exporter_database}?sslmode=require"

    volumes:
      prometheus_data:
      grafana_data:
    COMPOSE

    cat > /opt/monitoring/prometheus/prometheus.yml <<'PROM'
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ["localhost:9090"]

      - job_name: web-node-exporters
        static_configs:
          - targets:
              - "${var.web1_private_ip}:9100"
              - "${var.web2_private_ip}:9100"

      - job_name: postgres-exporter
        static_configs:
          - targets: ["postgres-exporter:9187"]
    PROM

    cat > /opt/monitoring/grafana/provisioning/datasources/prometheus.yml <<'GRAFANA_DS'
    apiVersion: 1

    datasources:
      - name: Prometheus
        uid: prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
        editable: true
    GRAFANA_DS

    cat > /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml <<'GRAFANA_DASH_CFG'
    apiVersion: 1

    providers:
      - name: Default
        orgId: 1
        folder: Node Exporter
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards
    GRAFANA_DASH_CFG

    rm -f /opt/monitoring/grafana/dashboards/*.json
    curl -fsSL https://grafana.com/api/dashboards/1860/revisions/latest/download -o /opt/monitoring/grafana/dashboards/node-exporter-full-1860.json

    chown -R root:root /opt/monitoring
    chmod -R 755 /opt/monitoring

    cd /opt/monitoring
    docker compose up -d
  EOF

  tags = {
    Name = var.instance_name
  }
}

resource "aws_eip" "monitoring" {
  domain = "vpc"

  tags = {
    Name = "${var.instance_name}-eip"
  }
}

resource "aws_eip_association" "monitoring" {
  instance_id   = aws_instance.monitoring.id
  allocation_id = aws_eip.monitoring.id
}
