# Terraform Main Configuration
# Core AWS infrastructure for ChatApp deployment

# ===================================================================
# VPC - Virtual Private Cloud
# ===================================================================
resource "aws_vpc" "chatapp" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )

  lifecycle {
    ignore_changes = [tags_all]
  }
}

# ===================================================================
# Internet Gateway
# ===================================================================
resource "aws_internet_gateway" "chatapp" {
  vpc_id = aws_vpc.chatapp.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-igw"
    }
  )

  lifecycle {
    ignore_changes = [tags_all]
  }
}

# ===================================================================
# Public Subnet
# ===================================================================
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.chatapp.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = var.associate_public_ip

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-subnet"
      Type = "Public"
    }
  )

  lifecycle {
    ignore_changes = [tags_all]
  }
}

# ===================================================================
# Route Table for Public Subnet
# ===================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.chatapp.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.chatapp.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )

  lifecycle {
    ignore_changes = [tags_all]
  }
}

# ===================================================================
# Route Table Association
# ===================================================================
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ===================================================================
# Security Group (see security_group.tf for detailed rules)
# ===================================================================
resource "aws_security_group" "chatapp" {
  name_prefix = "${var.project_name}-"
  description = "Security group for ${var.project_name} Kubernetes cluster"
  vpc_id      = aws_vpc.chatapp.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags_all]
  }
}

# ===================================================================
# Network ACL (optional, for additional network security)
# ===================================================================
resource "aws_network_acl" "chatapp" {
  vpc_id     = aws_vpc.chatapp.id
  subnet_ids = [aws_subnet.public.id]

  lifecycle {
    ignore_changes = [tags_all]
  }

  # Inbound rules
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 30000
    to_port    = 32767
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound rule
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nacl"
    }
  )
}

# ===================================================================
# Data source: Ubuntu AMI (most recent)
# ===================================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-${var.ubuntu_version}-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = [var.ami_root_device_type]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ===================================================================
# EC2 Instance - MicroK8s Primary Node
# ===================================================================
resource "aws_instance" "microk8s_primary" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.chatapp.id]

  # Enable detailed monitoring
  monitoring = true

  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-root-volume"
    }
  }

  # User data script for initial setup
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    project     = var.project_name
  }))

  tags = merge(
    var.tags,
    {
      Name = var.instance_name
      Role = "MicroK8s-Primary"
    }
  )

  lifecycle {
    ignore_changes = [
      user_data,
      ami,
      tags_all
    ]
  }

  depends_on = [aws_internet_gateway.chatapp]
}

# ===================================================================
# Elastic IP (Optional - for static public IP)
# ===================================================================
resource "aws_eip" "chatapp" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.microk8s_primary.id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-eip"
    }
  )

  depends_on = [aws_internet_gateway.chatapp]
}

# ===================================================================
# CloudWatch Log Group for EC2 Logs
# ===================================================================
resource "aws_cloudwatch_log_group" "chatapp" {
  name              = "/aws/ec2/${var.project_name}"
  retention_in_days = 30

  # FIX 1: Added `tags` to ignore_changes alongside `tags_all`.
  # Terraform calls ListTagsForResource to detect tag drift on every plan/apply.
  # Ignoring both `tags` and `tags_all` prevents that API call entirely,
  # which eliminates the 408 timeout error.
  lifecycle {
    ignore_changes = [tags, tags_all]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-logs"
    }
  )
}

# ===================================================================
# CloudWatch Alarms for EC2 Instance
# ===================================================================

# FIX 2: Added `treat_missing_data = "notBreaching"` to both alarms.
# Without this, if the EC2 instance is stopped or metrics are missing,
# the alarm goes into ALARM state unnecessarily.

resource "aws_cloudwatch_metric_alarm" "instance_status_check" {
  alarm_name          = "${var.project_name}-instance-status-check"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "This alarm monitors EC2 instance status checks"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.microk8s_primary.id
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when CPU exceeds 80%"
  treat_missing_data  = "notBreaching"
  alarm_actions       = []

  dimensions = {
    InstanceId = aws_instance.microk8s_primary.id
  }
}
