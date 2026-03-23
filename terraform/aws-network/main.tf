resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id

  tags = {
    Name = "cs1-main-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  tags = {
    Name = "cs1-main-rtb-public"
  }
}

resource "aws_route_table" "private1" {
  vpc_id = var.vpc_id

  tags = {
    Name = "cs1-main-rtb-private1-eu-central-1a"
  }
}

resource "aws_route_table" "private2" {
  vpc_id = var.vpc_id

  tags = {
    Name = "cs1-main-rtb-private2-eu-central-1b"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "cs1-main-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = var.subnet_public1_a_id

  tags = {
    Name = "cs1-main-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "private1_internet_access" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route" "private2_internet_access" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_security_group" "db" {
  name        = "DBSecurity"
  description = "Allow access to the database"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "db_postgres_from_web" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.web.id
  description              = "PostgreSQL from web tier"
}

resource "aws_security_group" "web" {
  name        = "WebSecurity"
  description = "Allow access to the web server"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  ssh_ingress_cidrs = [for cidr in split(",", var.ssh_ingress_cidr) : trimspace(cidr) if trimspace(cidr) != ""]
}

resource "aws_security_group_rule" "web_ssh_from_admin" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.web.id
  cidr_blocks       = local.ssh_ingress_cidrs
  description       = "SSH from admin CIDR"
}

resource "aws_route_table_association" "public1_assoc" {
  route_table_id = aws_route_table.public.id
  subnet_id      = var.subnet_public1_a_id
}

resource "aws_route_table_association" "public2_assoc" {
  route_table_id = aws_route_table.public.id
  subnet_id      = var.subnet_public2_b_id
}

resource "aws_route_table_association" "private1_assoc" {
  route_table_id = aws_route_table.private1.id
  subnet_id      = var.subnet_private1_a_id
}

resource "aws_route_table_association" "private2_assoc" {
  route_table_id = aws_route_table.private2.id
  subnet_id      = var.subnet_private2_b_id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private1.id, aws_route_table.private2.id]

  tags = {
    Name = "cs1-main-vpce-s3"
  }
}
