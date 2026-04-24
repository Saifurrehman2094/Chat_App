#!/bin/bash
# User Data Script for EC2 Instance Initialization
# This script runs as root when the instance starts

set -e  # Exit on any error

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "ChatApp EC2 Instance Initialization"
echo "Environment: ${environment}"
echo "Project: ${project}"
echo "========================================="
echo "Start time: $(date)"

# Update system packages
echo "[1/5] Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    net-tools \
    htop \
    awscli \
    unzip \
    jq \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Docker (required for microk8s containerd integration, optional)
echo "[2/5] Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker daemon
echo "[3/5] Starting Docker daemon..."
systemctl start docker
systemctl enable docker

# Install snapd (for microk8s)
echo "[4/5] Installing snapd..."
apt-get install -y snapd
systemctl start snapd
systemctl enable snapd

# Install kubectl (for local admin)
echo "[5/5] Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Create non-root user for microk8s (optional but recommended)
echo "Creating ubuntu user group membership..."
usermod -a -G docker ubuntu || true
usermod -a -G microk8s ubuntu || true

# Set hostname
hostnamectl set-hostname ${project}-microk8s-primary

# Create directories for cluster configuration
mkdir -p /opt/chatapp
mkdir -p /root/.kube
mkdir -p /home/ubuntu/.kube

# Download and store Ansible inventory template
echo "Preparing Ansible configuration..."
mkdir -p /opt/ansible
cat > /opt/ansible/README.txt << 'EOF'
Ansible will update this instance with:
1. MicroK8s installation and setup
2. ArgoCD deployment
3. Kubernetes manifest application
EOF

# Configure SSH for Ansible access
echo "Configuring SSH..."
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh

# Create a marker file indicating user-data completion
touch /var/lib/cloud/instance/boot-finished
echo "Boot finished at $(date)" > /var/log/boot-finished.txt

# CloudWatch agent installation (optional)
echo "Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

echo "========================================="
echo "User data script completed successfully"
echo "End time: $(date)"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Wait for Ansible provisioning"
echo "2. Run: microk8s status"
echo "3. Setup kubeconfig: microk8s config"
echo ""
