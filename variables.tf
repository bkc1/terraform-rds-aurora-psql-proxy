variable "aws_region" {
  description = "AWS region to launch resources"
  default     = "us-west-2"
}

variable "public_key_path" {
  description = "Path to the public key"
  default     = "keys/mykey.pub"
}

variable "private_key_path" {
  description = "Path to the priave key"
  default     = "keys/mykey"
} 

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "ec2_instance_type" {
  default = "t3.micro"
}

variable "rds_instance_type" {
  default = "db.r6g.large"
}

