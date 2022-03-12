
locals {
  name     = "myenv"
  region   = var.aws_region
  tags = {
    terraform_managed = "true"
    Environment       = "sandbox"
  }
}

provider "aws" {
  region = local.region
}

terraform {
  required_version = ">= 1.1.0"
}

# SSH key pair for EC2 instance
resource "aws_key_pair" "auth" {
  key_name   = local.name
  public_key = file(var.public_key_path)
}

# Harvest AMI ID
data "aws_ami" "amznlinux2" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["137112412989"] # Amazon
}

# This will fetch our account_id, no need to hard code it
data "aws_caller_identity" "current" {}
