# Terraform - RDS Aurora PostgreSQL with Proxy & IAM Authentication

## Overview

Terraform deploys a sandbox PostgreSQL environment on AWS Aurora with RDS Proxy. The database and Proxy endpoints must be accessed via the EC2 bastion host(VPC network). The EC2 instance automatically loads an example/test database called `world` via the `remote-exec` TF provisioner. An IAM user is created called `dbadmin`, along with all IAM roles/policies needed for RDS IAM authentication via the `dbadmin` user.   

## Terraform modules
The following modules are used:

* terraform-aws-modules/rds-aurora/aws
* terraform-aws-modules/security-group/aws


## Prereqs & Dependencies

This was developed and tested with Terraform `v1.1.3`, AWScli `v2.2.19`. It is strongly recommended to deploy this is a sandbox or non-production account.

* An AWS-cli configuration with elevated IAM permissions must be in place. The IAM access and secret keys in the AWS-cli are needed by Terraform.
* In order for the EC2 instance to launch successfully, you must first create an SSH key pair in the 'keys' directory named `mykey`.

```
ssh-keygen -t rsa -f ./keys/mykey -N ""
```

## Usage

Set the desired AWS region and modify any default variables in the `variables.tf` file as needed. The AWS region defaults to `US-West-2`.

### Deploying with Terraform
```
terraform init  ## initialize Terraform
terraform plan  ## Review what Terraform will do
terraform apply ## Deploy the resources
terraform show -json |jq .values.outputs ## See redacted/sensitive Terraform outputs
```
Tear-down the resources in the stack
```
terraform destroy
```

### Methods to connect to the database

Capture the EC2 instance public IP address in the Terraform outputs and login via SSH using the SSH key pair you created above. `$RDSHOST` & `$PROXY` are automatically set in the environment.

```
ssh -i keys/mykey ec2-user@<public_ip>
```
Connect to the Aurora cluster endpoint with the `postgres` user/password and connect to `world` DB. Auto-generated password can be found in the Terraform outputs.
```
psql -h $RDSHOST -U postgres
Password for user postgres:
postgres=> \c world
You are now connected to database "world" as user "postgres".
world=>
```
Connect directly to the `world` DB via RDS Proxy endpoint using the `postgres` user & password.

```
psql -h $PROXY -U postgres -d world
```

Connect to the `world` DB via the Aurora cluster endpoint using the `dbadmin` user & IAM authentication. This uses EC2 Role perms, no password required.

```
export PGPASSWORD="$(aws rds generate-db-auth-token --hostname $RDSHOST --port 5432 --region us-west-2 --username dbadmin)"
psql -h $RDSHOST -U dbadmin -d world
```
