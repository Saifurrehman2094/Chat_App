# Terraform Variables
# Define all input variables for the ChatApp deployment

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "chatapp"
  validation {
    condition     = length(var.project_name) <= 20
    error_message = "Project name must be 20 characters or less."
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "Subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zone" {
  description = "AWS Availability Zone for the subnet"
  type        = string
  default     = "us-east-1a"
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type for microk8s cluster (t3.micro recommended, t2.micro if Free Tier available)"
  type        = string
  default     = "t3.micro"
  validation {
    condition     = can(regex("^t[2-4]\\.(micro|small|medium|large|xlarge)$", var.instance_type))
    error_message = "Instance type must be a valid t2, t3, or t4 instance type."
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 50
  validation {
    condition     = var.root_volume_size >= 30 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 30 and 1000 GB."
  }
}

variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be gp3, gp2, io1, or io2."
  }
}

# EC2 instance name
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "chatapp-microk8s-primary"
}

# Security
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: In production, restrict this to your IP
  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0
    error_message = "At least one SSH CIDR must be specified."
  }
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed for HTTP/HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Public IP
variable "associate_public_ip" {
  description = "Whether to associate a public IP with the instance"
  type        = bool
  default     = true
}

variable "use_elastic_ip" {
  description = "Whether to use an Elastic IP instead of auto-assigned public IP"
  type        = bool
  default     = false
}

# OS/AMI Configuration
variable "ami_owner_alias" {
  description = "AMI owner alias (ubuntu, amazon-linux, etc.)"
  type        = string
  default     = "ubuntu"
}

variable "ami_root_device_type" {
  description = "Root device type for AMI"
  type        = string
  default     = "ebs"
}

variable "ubuntu_version" {
  description = "Ubuntu version (20.04, 22.04, 24.04)"
  type        = string
  default     = "22.04"
  validation {
    condition     = contains(["20.04", "22.04", "24.04"], var.ubuntu_version)
    error_message = "Ubuntu version must be 20.04, 22.04, or 24.04."
  }
}

# Tagging
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default = {
    Application = "ChatApp"
    Deployment  = "Kubernetes"
  }
}

# SSH Key (Existing)
variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair for SSH access"
  type        = string
  # No default; user must provide this
}

# Network Configuration
variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

# Security Group Configuration
variable "enable_ipv6" {
  description = "Enable IPv6 CIDR block for VPC"
  type        = bool
  default     = false
}
