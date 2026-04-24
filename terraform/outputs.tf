# Terraform Outputs
# Export important infrastructure details for downstream tools (Ansible, kubectl, etc.)

# ===================================================================
# VPC Outputs
# ===================================================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.chatapp.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.chatapp.cidr_block
}

# ===================================================================
# Subnet Outputs
# ===================================================================
output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "subnet_cidr" {
  description = "CIDR block of the public subnet"
  value       = aws_subnet.public.cidr_block
}

# ===================================================================
# Internet Gateway Outputs
# ===================================================================
output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.chatapp.id
}

# ===================================================================
# Route Table Outputs
# ===================================================================
output "route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

# ===================================================================
# Security Group Outputs
# ===================================================================
output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.chatapp.id
}

output "security_group_name" {
  description = "Name of the security group"
  value       = aws_security_group.chatapp.name
}

# ===================================================================
# EC2 Instance Outputs (IMPORTANT FOR DEPLOYMENT)
# ===================================================================
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.microk8s_primary.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.microk8s_primary.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.microk8s_primary.public_ip
  sensitive   = false
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.microk8s_primary.public_dns
}

output "instance_ami_id" {
  description = "AMI ID used for the instance"
  value       = aws_instance.microk8s_primary.ami
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.microk8s_primary.arn
}

# ===================================================================
# Elastic IP Outputs (if enabled)
# ===================================================================
output "elastic_ip" {
  description = "Elastic IP address (if enabled)"
  value       = length(aws_eip.chatapp) > 0 ? aws_eip.chatapp[0].public_ip : null
}

output "elastic_ip_id" {
  description = "ID of the Elastic IP (if enabled)"
  value       = length(aws_eip.chatapp) > 0 ? aws_eip.chatapp[0].id : null
}

# ===================================================================
# CloudWatch Outputs
# ===================================================================
output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.chatapp.name
}

# ===================================================================
# SSH Connection String (for quick access)
# ===================================================================
output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i /path/to/key.pem ubuntu@${aws_instance.microk8s_primary.public_ip}"
}

# ===================================================================
# Summary Output for Documentation
# ===================================================================
output "deployment_summary" {
  description = "Summary of key deployment information"
  value = {
    instance_id     = aws_instance.microk8s_primary.id
    instance_type   = var.instance_type
    public_ip       = aws_instance.microk8s_primary.public_ip
    public_dns      = aws_instance.microk8s_primary.public_dns
    private_ip      = aws_instance.microk8s_primary.private_ip
    security_group  = aws_security_group.chatapp.name
    vpc_id          = aws_vpc.chatapp.id
    subnet_id       = aws_subnet.public.id
    region          = var.aws_region
    availability_zone = var.availability_zone
    ssh_user        = "ubuntu"
    ssh_key         = var.key_pair_name
    
    # Access endpoints
    nginx_http_endpoint = "http://${aws_instance.microk8s_primary.public_ip}:30080"
    nginx_https_endpoint = "https://${aws_instance.microk8s_primary.public_ip}:30443"
    
    # Kubernetes access
    kubectl_config_context = "${var.project_name}-microk8s"
    kubeconfig_location    = "~/.kube/config"
    
    # Application endpoints (after Kubernetes deployment)
    frontend_url = "http://${aws_instance.microk8s_primary.public_ip}:30080"
    api_url      = "http://${aws_instance.microk8s_primary.public_ip}:30080/api"
    websocket_url = "ws://${aws_instance.microk8s_primary.public_ip}:30080/socket.io"
  }
}
