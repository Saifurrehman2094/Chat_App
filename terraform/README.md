# Terraform Configuration for ChatApp Deployment

This directory contains all Terraform Infrastructure-as-Code (IaC) for provisioning AWS resources needed to run the ChatApp on MicroK8s.

## Overview

The Terraform configuration creates:

- **VPC** with public subnet in specified availability zone
- **Internet Gateway** for external access
- **Route Table** for public routing
- **Security Group** with Kubernetes-friendly rules
- **EC2 Instance** (t3.medium by default) configured for MicroK8s
- **CloudWatch Monitoring** for instance health
- **Optional Elastic IP** for static public IP

## Prerequisites

### Local Requirements

1. **Terraform** >= 1.0 installed ([download](https://www.terraform.io/downloads))
2. **AWS CLI** v2 installed ([download](https://aws.amazon.com/cli/))
3. **AWS Credentials** configured locally or via IAM role
   ```bash
   aws configure
   # OR set environment variables:
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   ```
4. **SSH Key Pair** created in AWS
   ```bash
   # In AWS Console or via CLI:
   aws ec2 create-key-pair --key-name chatapp-key --region us-east-1 \
     --query 'KeyMaterial' --output text > ~/.ssh/chatapp-key.pem
   chmod 600 ~/.ssh/chatapp-key.pem
   ```

### AWS Prerequisites

- AWS Account with sufficient permissions (EC2, VPC, CloudWatch)
- SSH key pair created in the target region
- Internet connectivity for instance outbound traffic

## File Structure

```
terraform/
├── versions.tf              # Provider configuration
├── variables.tf             # Input variables and validation
├── main.tf                  # Core infrastructure (VPC, EC2, etc.)
├── security_group.tf        # Detailed firewall rules
├── outputs.tf               # Output values for downstream use
├── user_data.sh             # EC2 initialization script
├── terraform.tfvars.example # Example variables (COPY THIS)
├── .gitignore               # Version control excludes
└── README.md                # This file
```

## Quick Start

### 1. Create terraform.tfvars from template

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars with your values

```bash
nano terraform.tfvars
# Key values to update:
# - aws_region: Your desired AWS region
# - key_pair_name: Name of your SSH key pair (MUST EXIST in AWS)
# - allowed_ssh_cidrs: Your IP or ["0.0.0.0/0"] for open access
# - use_elastic_ip: true if you want a static IP
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the deployment

```bash
terraform plan -out=tfplan
# Review the planned changes
```

### 5. Apply the configuration

```bash
terraform apply tfplan
```

### 6. Save outputs

```bash
terraform output -json > ../deployment-outputs.json
terraform output deployment_summary
```

## Important Variables

| Variable            | Default       | Description                               |
| ------------------- | ------------- | ----------------------------------------- |
| `aws_region`        | `us-east-1`   | AWS region for deployment                 |
| `instance_type`     | `t3.medium`   | EC2 instance type (2 vCPU, 4GB RAM)       |
| `root_volume_size`  | `50`          | Root volume size in GB                    |
| `key_pair_name`     | Required      | SSH key pair name (must exist in AWS)     |
| `vpc_cidr`          | `10.0.0.0/16` | VPC CIDR block                            |
| `subnet_cidr`       | `10.0.1.0/24` | Public subnet CIDR                        |
| `allowed_ssh_cidrs` | `0.0.0.0/0`   | IPs allowed SSH access (RESTRICT IN PROD) |
| `use_elastic_ip`    | `false`       | Use static Elastic IP                     |
| `environment`       | `dev`         | Environment name (dev/staging/prod)       |

## Terraform Commands

### Validate Configuration

```bash
terraform validate
terraform fmt -check .
terraform fmt -recursive .  # Auto-format files
```

### Plan Changes

```bash
terraform plan
terraform plan -var="instance_type=t3.large"  # Override variable
```

### Apply Changes

```bash
terraform apply
terraform apply -auto-approve  # Skip confirmation (use carefully)
```

### Destroy Resources

```bash
terraform destroy
terraform destroy -auto-approve  # Skip confirmation (use carefully)
terraform state list  # List resources
terraform state show aws_instance.microk8s_primary  # Show specific resource
```

### State Management

```bash
terraform state list                 # List all resources
terraform state show <resource>      # Show resource details
terraform state rm <resource>        # Remove from state (advanced)
terraform state backup              # Manual state backup
terraform refresh                   # Sync state with AWS
```

### Debug & Troubleshooting

```bash
terraform console  # Interactive console to test expressions
terraform validate -json  # Output validation in JSON format
terraform plan -json | jq '.'  # Pretty-print plan
terraform show -json | jq '.'  # Show state in JSON
TF_LOG=DEBUG terraform plan  # Verbose logging
```

## Outputs

After successful `terraform apply`, key outputs include:

```bash
terraform output instance_public_ip      # Public IP of EC2 instance
terraform output ssh_command             # SSH command to connect
terraform output deployment_summary      # Full deployment summary
```

### Access Your Instance

```bash
# Using output from Terraform
INSTANCE_IP=$(terraform output -raw instance_public_ip)
ssh -i ~/.ssh/chatapp-key.pem ubuntu@$INSTANCE_IP

# Or use the ssh_command output
$(terraform output -raw ssh_command)
```

## Security Best Practices

1. **SSH Access**: Restrict `allowed_ssh_cidrs` to specific IPs in production

   ```hcl
   allowed_ssh_cidrs = ["YOUR_IP/32"]
   ```

2. **Elastic IP**: Use `use_elastic_ip = true` for static IP

   ```hcl
   use_elastic_ip = true
   ```

3. **State File**: Protect `terraform.tfstate`

   ```bash
   chmod 600 terraform.tfstate
   # Consider using remote state (S3 + DynamoDB)
   ```

4. **Key Pair**: Keep SSH private key secure

   ```bash
   chmod 600 ~/.ssh/chatapp-key.pem
   ```

5. **IAM Permissions**: Use least-privilege IAM policy
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": ["ec2:*", "vpc:*", "cloudwatch:*"],
         "Resource": "*"
       }
     ]
   }
   ```

## Remote State Backend (Recommended for Teams)

To store state remotely (S3 + DynamoDB):

1. Create S3 bucket and DynamoDB table:

```bash
aws s3api create-bucket --bucket chatapp-terraform-state --region us-east-1
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

2. Uncomment backend configuration in `versions.tf`:

```hcl
backend "s3" {
  bucket         = "chatapp-terraform-state"
  key            = "chatapp/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

3. Reinitialize:

```bash
terraform init
```

## Troubleshooting

### Instance Not Starting

```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id> --region <region>

# Check system logs
aws ec2 get-console-output --instance-id <instance-id> --region <region>
```

### SSH Connection Denied

```bash
# Verify security group allows SSH
aws ec2 describe-security-groups --group-ids <sg-id>

# Test connectivity
nc -zv <public-ip> 22
```

### Terraform State Conflict

```bash
# Refresh state
terraform refresh

# Force unlock (if stuck)
terraform force-unlock <LOCK_ID>
```

## Cost Estimation

Rough monthly costs on AWS (us-east-1):

- **t3.medium**: ~$30 (732 hours/month)
- **50GB GP3 volume**: ~$4
- **Data transfer**: ~$0-10 (depends on usage)
- **Total**: ~$35-45/month

For cost estimates:

```bash
terraform plan | grep -i "will be.*"
```

## Next Steps

After Terraform completes:

1. **Verify Instance**

   ```bash
   INSTANCE_IP=$(terraform output -raw instance_public_ip)
   ssh -i ~/.ssh/chatapp-key.pem ubuntu@$INSTANCE_IP
   ```

2. **Run Ansible Playbook** (see ../ansible/README.md)

   ```bash
   cd ../ansible
   ansible-playbook -i inventory.ini playbook.yml
   ```

3. **Deploy with ArgoCD** (see ../argocd/README.md)

   ```bash
   kubectl apply -f ../argocd/application.yaml
   ```

4. **Verify Deployment**
   ```bash
   kubectl get pods -n chatapp
   kubectl logs -n chatapp pod/frontend-xxx
   ```

## Support & Documentation

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [MicroK8s Documentation](https://microk8s.io/docs)

## Contributing

When modifying Terraform files:

1. Run `terraform validate`
2. Run `terraform fmt -recursive .`
3. Run `terraform plan` to verify changes
4. Update documentation if variables change
5. Commit `*.tf`, `*.tfvars.example`, and documentation
6. NEVER commit `*.tfvars`, `*.tfstate`, or `.terraform/`
