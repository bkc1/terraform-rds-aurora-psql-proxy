
resource "aws_iam_instance_profile" "bastion" {
  name = local.name
  role = aws_iam_role.bastion.name
}

# IAM role for EC2 instance
resource "aws_iam_role" "bastion" {
  name               = local.name
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# IAM user with for DB Auth
resource "aws_iam_user" "dbuser" {
  name = "dbadmin"
}

# IAM policy for Aurora IAM auth, dbadmin user created via SQL script
resource "aws_iam_policy" "rdsconnect" {
  name        = "${local.name}-rds-connect-policy"
  description = "Allows IAM auth to Aurora"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds-db:connect"
            ],
            "Resource": [
                "arn:aws:rds-db:${local.region}:${data.aws_caller_identity.current.account_id}:dbuser:${module.aurora.cluster_resource_id}/dbadmin",
                "arn:aws:rds-db:${local.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_proxy.myEnv.arn}/dbadmin",
            ]
        }
    ]
  })
}

# Attached policy to EC2 instance role
resource "aws_iam_role_policy_attachment" "rdsconnect-attach" {
  role       = aws_iam_role.bastion.name
  policy_arn = aws_iam_policy.rdsconnect.arn
}

# EC2 spot instance to access the Aurora DB via the proxy, 
resource "aws_spot_instance_request" "bastion" {
  wait_for_fulfillment    = true
  instance_type           = var.ec2_instance_type
  ami                     = data.aws_ami.amznlinux2.id
  key_name                = aws_key_pair.auth.id
  vpc_security_group_ids  = [module.ec2_sg.security_group_id]
  iam_instance_profile    = aws_iam_instance_profile.bastion.name
  subnet_id               = element(module.vpc.public_subnets, 0)
  root_block_device {
    delete_on_termination = true
    volume_type           = "standard"
  }
  # Apply tag to spot instance
  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=Name,Value=bastion-instance --region ${var.aws_region}"
  }
  #Connection settings for remote SSH
  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file(var.private_key_path)
  }
  # Upload SQL script
  provisioner "file" {
    source      = "./world.sql"
    destination = "/home/ec2-user/world.sql"
  }
  # Install Postgres & exec SQL script to load schema and data. Note the Terraform creates the 'world' DB on creation of Aurora
  provisioner "remote-exec" {
    inline = [
      "sleep 3",
      "sudo yum -y install postgresql",
      "echo 'export RDSHOST=${module.aurora.cluster_endpoint}' >> ~/.bashrc",
      "echo 'export PROXY=${aws_db_proxy.myEnv.endpoint}' >> ~/.bashrc",
      "echo 'export REGION=${var.aws_region}' >> ~/.bashrc",
      "PGPASSWORD='${module.aurora.cluster_master_password}' psql -h ${module.aurora.cluster_endpoint} -U ${module.aurora.cluster_master_username} -d ${module.aurora.cluster_database_name} -f ~/world.sql"
    ]
  }
  # DB and proxy must be available before EC2 provisioning can complete
  depends_on = [module.aurora, aws_db_proxy_target.myEnv]
  tags = local.tags
}
