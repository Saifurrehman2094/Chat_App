# Security Group Rules for ChatApp
# Detailed ingress and egress rules for the application

# ===================================================================
# SSH Access (for cluster administration)
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  description              = "SSH access for cluster administration"
  from_port                = 22
  to_port                  = 22
  ip_protocol              = "tcp"
  cidr_ipv4                = join(",", var.allowed_ssh_cidrs)
  security_group_id        = aws_security_group.chatapp.id

  tags = {
    Name = "ssh-access"
  }
}

# ===================================================================
# HTTP Access (Frontend and API Gateway)
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "http" {
  description       = "HTTP access to nginx gateway (port 30080)"
  from_port         = 30080
  to_port           = 30080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "http-access"
  }
}

# ===================================================================
# HTTPS Access (Future TLS termination)
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "https" {
  description       = "HTTPS access (future TLS termination)"
  from_port         = 30443
  to_port           = 30443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "https-access"
  }
}

# ===================================================================
# Kubernetes Node Port Range (30000-32767)
# Used for all microservices except nginx gateway (which uses specific ports)
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "k8s_nodeport" {
  description       = "Kubernetes NodePort range for services"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "k8s-nodeport"
  }
}

# ===================================================================
# DNS Resolution (UDP 53)
# Needed for internal DNS lookups within the cluster
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "dns" {
  description       = "DNS resolution"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = var.vpc_cidr
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "dns-resolution"
  }
}

# ===================================================================
# Internal Communication within VPC
# Allows all protocols between instances in the same VPC
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "internal_all" {
  description       = "Internal VPC communication"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "internal-tcp"
  }
}

resource "aws_vpc_security_group_ingress_rule" "internal_udp" {
  description       = "Internal UDP communication"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "udp"
  cidr_ipv4         = var.vpc_cidr
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "internal-udp"
  }
}

# ===================================================================
# ICMP (ping) for network diagnostics
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "icmp" {
  description       = "ICMP for network diagnostics"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "icmp-ping"
  }
}

# ===================================================================
# Egress Rules - Allow all outbound traffic
# ===================================================================
resource "aws_vpc_security_group_egress_rule" "all_traffic" {
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  security_group_id = aws_security_group.chatapp.id

  tags = {
    Name = "all-outbound"
  }
}

# ===================================================================
# Self-referencing rule for inter-pod communication
# ===================================================================
resource "aws_vpc_security_group_ingress_rule" "self_reference" {
  description              = "Allow traffic from instances in the same security group"
  from_port                = 0
  to_port                  = 65535
  ip_protocol              = "tcp"
  referenced_security_group_id = aws_security_group.chatapp.id
  security_group_id        = aws_security_group.chatapp.id

  tags = {
    Name = "self-reference"
  }
}
