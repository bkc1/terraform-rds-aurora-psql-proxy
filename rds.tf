resource "random_password" "master" {
  length  = 12
  special = false
}

# Get ARN for default KMS key for Secrets Manager
data "aws_kms_key" "defaultSecManager" {
  key_id = "alias/aws/secretsmanager"
}

# IAM policy template for RDS proxy, using default, managed KMS key for Secrets Manager
data "template_file" "policy-tpl" {
  template = file("${path.root}/templates/rds-proxy.tpl")
  vars = {
    region    = var.aws_region
    secret_arn = aws_secretsmanager_secret.myEnv.arn
    key_arn   = data.aws_kms_key.defaultSecManager.arn
  }
}

# Create Proxy IAM policy, rendering template
resource "aws_iam_policy" "rdsproxy" {
  name   = "${local.name}-rdsproxy-policy"
  policy = data.template_file.policy-tpl.rendered
}

# IAM role for RDS proxy
resource "aws_iam_role" "rdsproxy" {
  name               = "${local.name}-rdsproxy-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach IAM policy to Proxy IAM role
resource "aws_iam_role_policy_attachment" "rdsproxy-attach" {
  role       = aws_iam_role.rdsproxy.name
  policy_arn = aws_iam_policy.rdsproxy.arn
}

# Create Aurora DB using registry module
module "aurora" {
  source = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 6.1.4"

  name           = local.name
  engine         = "aurora-postgresql"
  engine_version = "12.9"
  instances = {
    1 = {
      identifier     = "${local.name}-instance-1"
      instance_class      = var.rds_instance_type
      publicly_accessible = false
    }
    2 = {
      identifier     = "${local.name}-instance-2"
      instance_class = var.rds_instance_type
    }
  }

  vpc_id                 = module.vpc.vpc_id
  db_subnet_group_name   = local.name
  create_db_subnet_group = true
  subnets                = module.vpc.private_subnets
  create_security_group  = false
  vpc_security_group_ids = [module.db_sg.security_group_id]
  allowed_cidr_blocks    = module.vpc.public_subnets_cidr_blocks
  iam_database_authentication_enabled = true
  # Automatically create 'world" database in prep for SQL script
  database_name                       = "world"
  master_username                     = "postgres"
  master_password                     = random_password.master.result
  create_random_password              = false

  apply_immediately   = true
  skip_final_snapshot = true

  db_parameter_group_name         = aws_db_parameter_group.myEnv.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.myEnv.id
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.tags
}

resource "aws_db_parameter_group" "myEnv" {
  name        = "${local.name}-aurora-db-postgres12-parameter-group"
  family      = "aurora-postgresql12"
  description = "${local.name}-aurora-db-postgres12-parameter-group"
  tags        = local.tags
}

resource "aws_rds_cluster_parameter_group" "myEnv" {
  name        = "${local.name}-aurora-postgres12-cluster-parameter-group"
  family      = "aurora-postgresql12"
  description = "${local.name}-aurora-postgres12-cluster-parameter-group"
  tags        = local.tags
}

# Create RDS Proxy 
resource "aws_db_proxy" "myEnv" {
  name                   = local.name
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rdsproxy.arn
  vpc_security_group_ids = [module.proxy_sg.security_group_id]
  vpc_subnet_ids         = module.vpc.private_subnets[*]

  auth {
    auth_scheme = "SECRETS"
    description = "${local.name}-aurora-pw"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.myEnv.arn
  }

  tags = local.tags
}

resource "aws_db_proxy_default_target_group" "myEnv" {
  db_proxy_name = aws_db_proxy.myEnv.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
  }
}

resource "aws_db_proxy_target" "myEnv" {
  db_cluster_identifier  = module.aurora.cluster_id
  db_proxy_name          = aws_db_proxy.myEnv.name
  target_group_name      = aws_db_proxy_default_target_group.myEnv.name
  depends_on = [module.aurora]
}
