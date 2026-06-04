# sample.tf — comprehensive HCL/Terraform syntax fixture for parser testing.
# Covers: providers, variables, locals, data sources, resources, modules,
# outputs, provisioners, lifecycle, expressions, for loops, dynamic blocks,
# conditionals, functions, backends, moved blocks, check blocks.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  backend "s3" {
    bucket         = "tf-state-example"
    key            = "env/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tf-lock"
  }
}

# --------------------------------------------------------------------------- #
# Variables
# --------------------------------------------------------------------------- #

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod. Got: ${var.environment}"
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/8", "172.16.0.0/12"]
}

variable "db_config" {
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    storage_gb     = number
  })
  default = {
    engine         = "postgres"
    engine_version = "15.4"
    instance_class = "db.t3.micro"
    storage_gb     = 20
  }
}

# --------------------------------------------------------------------------- #
# Locals
# --------------------------------------------------------------------------- #

locals {
  name_prefix = "sample-${var.environment}"

  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "sample"
  })

  azs = ["${var.region}a", "${var.region}b", "${var.region}c"]

  subnet_cidrs = {
    public  = [for i, az in local.azs : cidrsubnet("10.0.0.0/16", 8, i)]
    private = [for i, az in local.azs : cidrsubnet("10.0.0.0/16", 8, i + 10)]
  }

  is_prod   = var.environment == "prod"
  min_count = local.is_prod ? 3 : 1
}

# --------------------------------------------------------------------------- #
# Provider
# --------------------------------------------------------------------------- #

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# --------------------------------------------------------------------------- #
# Data sources
# --------------------------------------------------------------------------- #

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# --------------------------------------------------------------------------- #
# Resources
# --------------------------------------------------------------------------- #

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  count = length(local.azs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_cidrs.public[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = { for i, az in local.azs : az => local.subnet_cidrs.private[i] }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${local.name_prefix}-private-${each.key}"
    Tier = "private"
  }
}

resource "aws_security_group" "web" {
  name   = "${local.name_prefix}-web-sg"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "app" {
  count = local.min_count

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl enable --now nginx
  EOF

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  monitoring = var.enable_monitoring

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [ami]

    precondition {
      condition     = var.instance_type != "t2.micro"
      error_message = "t2.micro is deprecated; use t3.micro or larger."
    }
  }

  tags = {
    Name  = "${local.name_prefix}-app-${count.index + 1}"
    Index = tostring(count.index)
  }
}

resource "aws_db_instance" "postgres" {
  count = local.is_prod ? 1 : 0

  identifier        = "${local.name_prefix}-db-${random_id.suffix.hex}"
  engine            = var.db_config.engine
  engine_version    = var.db_config.engine_version
  instance_class    = var.db_config.instance_class
  allocated_storage = var.db_config.storage_gb
  storage_encrypted = true
  skip_final_snapshot = !local.is_prod

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}

resource "aws_db_subnet_group" "main" {
  count = local.is_prod ? 1 : 0

  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

# --------------------------------------------------------------------------- #
# Moved block
# --------------------------------------------------------------------------- #

moved {
  from = aws_instance.old_app
  to   = aws_instance.app
}

# --------------------------------------------------------------------------- #
# Check block (Terraform 1.5+)
# --------------------------------------------------------------------------- #

check "instance_count_healthy" {
  assert {
    condition     = length(aws_instance.app) >= local.min_count
    error_message = "Expected >= ${local.min_count} instances, got ${length(aws_instance.app)}"
  }
}

# --------------------------------------------------------------------------- #
# Module
# --------------------------------------------------------------------------- #

module "cdn" {
  source = "./modules/cloudfront"

  origin_domain = aws_instance.app[0].public_dns
  environment   = var.environment
  tags          = local.common_tags
}

# --------------------------------------------------------------------------- #
# Outputs
# --------------------------------------------------------------------------- #

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [for s in aws_subnet.private : s.id]
}

output "instance_public_ips" {
  description = "Public IPs of app instances"
  value       = aws_instance.app[*].public_ip
  sensitive   = false
}

output "db_endpoint" {
  description = "PostgreSQL endpoint (prod only)"
  value       = local.is_prod ? aws_db_instance.postgres[0].endpoint : null
  sensitive   = true
}
