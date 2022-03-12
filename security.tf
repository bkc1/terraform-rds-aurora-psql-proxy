# Security Group for Aurora
module "db_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.8"

  name        = "${local.name}-rds-aurora"
  description = "RDS PostgreSQL security group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      description = "PostgreSQL access from RDS Proxy"
      source_security_group_id = module.proxy_sg.security_group_id
    },
  ]
  ingress_rules       = ["postgresql-tcp"]
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  egress_rules        = ["all-all"]

  tags = local.tags
}

#Security Group for RDS proxy
module "proxy_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.8"

  name        = "${local.name}-rds-proxy"
  description = "RDS Proxy security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["postgresql-tcp"]
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  egress_rules        = ["all-all"]

  tags = local.tags
}

# Security group for EC2 instance
module "ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "~> 4.8"

  name               = "${local.name}-ec2"
  description        = "EC2 security group"
  vpc_id             = module.vpc.vpc_id
  
  ingress_rules       = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  
  tags = local.tags
}

# Secrets Manager for RDS Proxy
resource "aws_secretsmanager_secret" "myEnv" {
  name_prefix =  "/${local.name}/aurora"
  tags        = local.tags
}

# Secret values, based off Aurora U/PW
resource "aws_secretsmanager_secret_version" "myEnv" {
  secret_id     = aws_secretsmanager_secret.myEnv.id
  secret_string = jsonencode({
    username = module.aurora.cluster_master_username
    password = module.aurora.cluster_master_password
    host     = module.aurora.cluster_endpoint
    port     = 5432
    dbClusterIdentifier = module.aurora.cluster_id
  })
}
