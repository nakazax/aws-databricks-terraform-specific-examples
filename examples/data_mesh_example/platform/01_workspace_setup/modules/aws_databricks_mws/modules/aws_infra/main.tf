# =============================================================================
# VPC Configuration
# =============================================================================
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc"
  })
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnets" {
  count                   = length(var.private_subnet_pair)
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.private_subnet_pair[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.prefix}-subnet-${count.index}"
  }
}

resource "aws_eip" "nat_gateway_elastic_ips" {
  count = length(var.public_subnets_cidr)
}

resource "aws_nat_gateway" "nat_gateways" {
  count         = length(var.public_subnets_cidr)
  allocation_id = aws_eip.nat_gateway_elastic_ips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private_route_tables" {
  count  = length(var.private_subnet_pair)
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateways[0].id
  }
}

resource "aws_route_table_association" "public_route_table_associations" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_route_table_associations" {
  count          = length(var.private_subnet_pair)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_tables[count.index].id
}

# =============================================================================
# Security groups
# =============================================================================
resource "aws_security_group" "test_sg" {
  name        = "default-security-group-${var.prefix}"
  description = "Default security group for ${var.prefix}"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =============================================================================
# S3 bucket
# =============================================================================
resource "aws_s3_bucket" "root_storage_bucket" {
  bucket        = "${var.prefix}-rootbucket"
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${var.prefix}-rootbucket"
  })
}

resource "aws_s3_bucket_public_access_block" "root_storage_bucket" {
  bucket             = aws_s3_bucket.root_storage_bucket.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.root_storage_bucket]
}

data "databricks_aws_bucket_policy" "this" {
  bucket = aws_s3_bucket.root_storage_bucket.bucket
}

resource "aws_s3_bucket_policy" "root_bucket_policy" {
  bucket = aws_s3_bucket.root_storage_bucket.id
  policy = data.databricks_aws_bucket_policy.this.json
}

# =============================================================================
# IAM roles and policies
# =============================================================================
data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

resource "aws_iam_role" "cross_account_role" {
  name               = "${var.prefix}-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = var.tags
}

data "databricks_aws_crossaccount_policy" "this" {
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.prefix}-policy"
  role   = aws_iam_role.cross_account_role.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}
