# 🚀 ChatApp Automated Deployment Guide

**Comprehensive Deployment Setup for AWS EC2 + Kubernetes + GitOps**

## ⚡ Quick Navigation

📍 **Just starting?** → Start here: [Quick Start (30 min)](#quick-start-deployment)

📍 **Need architecture details?** → [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

📍 **Following step-by-step?** → [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

📍 **Hit a problem?** → [Troubleshooting Guide](docs/DEPLOYMENT.md#troubleshooting)

---

## 📦 What You're Getting

This deployment package includes everything needed to run ChatApp in production on AWS:

| Component             | Technology            | Status                                                    |
| --------------------- | --------------------- | --------------------------------------------------------- |
| 🐳 **Containers**     | Docker                | ✅ 4 optimized Dockerfiles                                |
| 🏗️ **Infrastructure** | Terraform             | ✅ AWS VPC, EC2, Security Groups                          |
| ⚙️ **Configuration**  | Ansible               | ✅ 4 automation roles (Docker, MicroK8s, kubectl, ArgoCD) |
| ☸️ **Orchestration**  | Kubernetes (microk8s) | ✅ 14 production manifests                                |
| 🚀 **CI/CD**          | GitHub Actions        | ✅ Automated builds & deployments                         |
| 🔄 **GitOps**         | ArgoCD                | ✅ Declarative sync from repo                             |
| 📚 **Documentation**  | Complete guides       | ✅ Architecture, deployment, troubleshooting              |

---

## 🎯 Quick Start Deployment

### Prerequisites (5 min setup)

**On your local machine:**

```bash
# Install required tools
brew install terraform ansible awscli  # macOS
sudo apt-get install terraform ansible awscli  # Ubuntu

# Verify installations
terraform version    # >= 1.0
ansible --version    # >= 2.9
aws --version        # >= 2.0
```

**On AWS:**

```bash
# 1. Create SSH key pair
aws ec2 create-key-pair --key-name chatapp-key --region us-east-1 \
  --query 'KeyMaterial' --output text > ~/.ssh/chatapp-key.pem
chmod 600 ~/.ssh/chatapp-key.pem

# 2. Configure AWS CLI
aws configure
# Enter credentials and default region (us-east-1)

# 3. Verify AWS access
aws sts get-caller-identity
```

**GitHub (for CI/CD):**

1. Fork the Chat_App repository
2. Add GitHub secrets: `Settings → Secrets and variables → Actions`
   - `DOCKER_USERNAME`: Docker Hub username
   - `DOCKER_PASSWORD`: Docker Hub personal access token
   - `EC2_INSTANCE_IP`: (Add after Terraform creates instance)

---

### One-Command Deployment

```bash
# Copy and paste this entire block:

# ============================================
# 1. Setup Terraform
# ============================================
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (AWS region, key pair name, etc.)
# nano terraform.tfvars
# For now, just update key_pair_name and allowed_ssh_cidrs

# Initialize and apply
terraform init
EC2_IP=$(terraform apply -auto-approve -json | jq -r '.instance_public_ip.value')
echo "✅ EC2 Instance created: $EC2_IP"

# ============================================
# 2. Setup Ansible
# ============================================
cd ../ansible
sed -i.bak "s/<INSTANCE_PUBLIC_IP>/$EC2_IP/g" inventory.ini

# Wait for EC2 to be ready
sleep 60

# Run configuration
ansible-playbook -i inventory.ini playbook.yml -v
echo "✅ Kubernetes cluster ready"

# ============================================
# 3. Deploy Application
# ============================================
cd ../k8s

# Create secrets
kubectl create secret generic mysql-credentials \
  --from-literal=mysql-root-password=rootpassword \
  --from-literal=mysql-user=chatuser \
  --from-literal=mysql-password=chatpassword \
  -n chatapp 2>/dev/null || true

kubectl create secret generic backend-secrets \
  --from-literal=JWT_SECRET=your-secret-key \
  --from-literal=FRONTEND_URL=http://$EC2_IP:30080 \
  -n chatapp 2>/dev/null || true

# Deploy application
kubectl apply -k .

# Wait for pods
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=chatapp -n chatapp --timeout=300s

# ============================================
# 4. Get Access Information
# ============================================
echo ""
echo "✅ DEPLOYMENT COMPLETE!"
echo ""
echo "Frontend:   http://$EC2_IP:30080"
echo "ArgoCD:     http://$EC2_IP:30081"
echo ""
ARGOCD_PASS=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "ArgoCD Username: admin"
echo "ArgoCD Password: $ARGOCD_PASS"
echo ""
echo "SSH Access: ssh -i ~/.ssh/chatapp-key.pem ubuntu@$EC2_IP"
```

**That's it!** Your ChatApp is now deployed. 🎉

---

## 📋 Detailed Deployment Steps

### Phase 1: Infrastructure (Terraform)

```bash
cd terraform

# Step 1: Customize configuration
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Required changes:
# - key_pair_name: Your AWS SSH key pair name
# - allowed_ssh_cidrs: Your IP/CIDR (get from: curl checkip.amazonaws.com)
# Optional changes:
# - aws_region: Change if not using us-east-1
# - instance_type: t3.medium is recommended
# - ebs_volume_size: Currently 50GB

# Step 2: Deploy infrastructure
terraform init
terraform plan
terraform apply

# Step 3: Save outputs
terraform output -json > ../deployment-info.json
EC2_IP=$(terraform output -raw instance_public_ip)
echo "Instance IP: $EC2_IP"
```

⏱️ **Duration:** ~5 minutes  
**What happens:** AWS creates VPC, subnet, security group, EC2 instance  
**Next:** EC2 instance initializes (wait ~2 minutes for user-data script to complete)

---

### Phase 2: Configuration (Ansible)

```bash
cd ansible

# Step 1: Update inventory with EC2 IP
sed -i "s/<INSTANCE_PUBLIC_IP>/$EC2_IP/g" inventory.ini
cat inventory.ini | grep ansible_host

# Step 2: Test connection (should say "pong")
ansible all -i inventory.ini -m ping

# Step 3: Run playbook
# This takes ~3-5 minutes
ansible-playbook -i inventory.ini playbook.yml

# Step 4: Verify completion
ansible k8s_nodes -i inventory.ini -m shell \
  -a "/snap/bin/microk8s status"
```

⏱️ **Duration:** ~5-8 minutes  
**What happens:** Installs Docker, MicroK8s, kubectl, ArgoCD, enables addons  
**Next:** MicroK8s cluster is ready to accept deployments

---

### Phase 3: Application (Kubernetes)

```bash
cd k8s

# Step 1: Create secrets (required for services to connect)
kubectl create namespace chatapp  # Or skip if already exists
kubectl create secret generic mysql-credentials \
  --from-literal=mysql-root-password=rootpassword \
  --from-literal=mysql-user=chatuser \
  --from-literal=mysql-password=chatpassword \
  -n chatapp

# Step 2: Deploy application
kubectl apply -k .

# Step 3: Monitor deployment
kubectl get pods -n chatapp -w

# Wait for all pods to be Ready (Ctrl+C to exit)

# Step 4: Verify services
kubectl get svc -n chatapp
```

⏱️ **Duration:** ~2-3 minutes  
**What happens:** Deploys MySQL, Backend, Frontend, Nginx to cluster  
**Next:** All pods should be Running and Ready

---

### Phase 4: Verification

```bash
# Test frontend
curl -I http://$EC2_IP:30080/

# Test API
curl http://$EC2_IP:30080/api/health

# View ArgoCD
ARGOCD_PASS=$(kubectl get secret -n argocd argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
echo "ArgoCD: http://$EC2_IP:30081"
echo "Password: $ARGOCD_PASS"

# Check all pods
kubectl get pods -A
```

✅ **Success indicators:**

- Frontend page loads in browser
- API returns JSON response
- All pods show "Running"
- ArgoCD accessible with password

---

## 📂 File Structure

```
terraform/
├── versions.tf               # Provider configuration
├── variables.tf              # Input variables
├── main.tf                   # VPC, EC2, IAM
├── security_group.tf         # Firewall rules
├── outputs.tf                # Export values
├── user_data.sh              # EC2 init script
├── terraform.tfvars.example  # ← COPY THIS AND EDIT
└── README.md                 # Detailed Terraform guide

ansible/
├── playbook.yml              # Main orchestration
├── inventory.ini             # Hosts and variables
└── roles/
    ├── common/               # Docker + system packages
    ├── microk8s/             # Kubernetes setup
    ├── kubectl/              # kubectl + Helm
    └── argocd/               # ArgoCD deployment

k8s/
├── namespace.yaml            # chatapp namespace
├── configmap.yaml            # Configuration
├── secrets-template.yaml     # Secrets template
├── kustomization.yaml        # Compose all manifests
└── (mysql|backend|frontend|nginx)/
    ├── deployment.yaml       # Service definition
    ├── service.yaml          # Network exposure
    └── pvc.yaml              # Storage (MySQL only)

.github/workflows/
└── deploy.yml                # CI/CD pipeline

argocd/
└── application.yaml          # GitOps configuration

docs/
├── ARCHITECTURE.md           # Design & diagrams
├── DEPLOYMENT.md             # Complete step-by-step
└── TROUBLESHOOTING.md        # Common issues & fixes
```

---

## 🔧 Configuration Files

### Key Files to Edit

**1. `terraform/terraform.tfvars`** (REQUIRED)

```hcl
aws_region                  = "us-east-1"
key_pair_name              = "chatapp-key"        # ← Your SSH key name
instance_type              = "t3.medium"          # Good for dev
ebs_volume_size            = "50"                 # GB
allowed_ssh_cidrs          = ["YOUR_IP/32"]       # ← Your IP address
enable_detailed_monitoring = true
```

**2. `ansible/inventory.ini`** (REQUIRED)

```ini
[k8s_nodes]
ec2-instance ansible_host=<INSTANCE_PUBLIC_IP>   # ← Updated by script
                ansible_user=ubuntu
                ansible_ssh_private_key_file=~/.ssh/chatapp-key.pem
```

**3. `k8s/secrets-template.yaml`** (EDIT BEFORE APPLYING)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-credentials
  namespace: chatapp
type: Opaque
stringData:
  mysql-root-password: "rootpassword" # ← Change these!
  mysql-user: "chatuser"
  mysql-password: "chatpassword"
```

---

## 🐛 Quick Troubleshooting

### "SSH Connection Timeout"

```bash
# Your IP not in security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx --protocol tcp --port 22 --cidr YOUR_IP/32
```

### "Pods in Pending state"

```bash
# Check why pod can't start
kubectl describe pod POD_NAME -n chatapp
kubectl logs POD_NAME -n chatapp

# Usually: PVC not bound or image not found
```

### "Frontend shows blank page"

```bash
# Check logs
kubectl logs deployment/frontend -n chatapp
kubectl logs deployment/nginx-gateway -n chatapp

# Issue: Wrong backend URL in frontend env vars
```

**Full troubleshooting guide:** [docs/DEPLOYMENT.md#troubleshooting](docs/DEPLOYMENT.md#troubleshooting)

---

## 📊 What Gets Created

### AWS Resources

- ✅ VPC (10.0.0.0/16)
- ✅ Public Subnet (10.0.1.0/24)
- ✅ Internet Gateway
- ✅ Route Table
- ✅ Security Group (SSH, HTTP, HTTPS, Kubernetes)
- ✅ EC2 t3.medium instance
- ✅ 50GB GP3 EBS volume
- ✅ CloudWatch logs and alarms

### Kubernetes Services

- ✅ 1 MySQL pod (with persistent storage)
- ✅ 2 Backend pods (Express.js API)
- ✅ 2 Frontend pods (React SPA)
- ✅ 1 Nginx gateway (reverse proxy, NodePort)
- ✅ ArgoCD (on port 30081)
- ✅ Internal DNS resolution
- ✅ Health checks (liveness + readiness)

### CI/CD & GitOps

- ✅ GitHub Actions workflow (builds on push)
- ✅ ArgoCD app (auto-syncs manifests)
- ✅ Docker Hub image repository
- ✅ Git-based deployment history

---

## 💾 Backup & Recovery

### Backup Application

```bash
# Backup database
kubectl exec -it deployment/mysql -n chatapp -- \
  mysqldump -u root -p<password> chat_app > backup.sql

# Backup manifests
kubectl get all -A -o yaml > cluster-backup.yaml

# Backup Terraform state
aws s3 cp terraform.tfstate s3://your-bucket/
```

### Recover from Backup

```bash
# Recreate infrastructure
terraform apply

# Restore database
kubectl exec -i deployment/mysql -n chatapp -- \
  mysql -u root -p<password> < backup.sql
```

---

## 🔐 Security Recommendations

**Currently Configured:**

- ✅ Non-root container users
- ✅ Network security groups
- ✅ Kubernetes secrets for credentials
- ✅ Health checks for availability
- ✅ RBAC-ready manifests

**Recommended for Production:**

- 🔒 Enable HTTPS (certificates via cert-manager)
- 🔒 Restrict SSH to your IP only (not 0.0.0.0/0)
- 🔒 Use Sealed Secrets or External Secrets Operator
- 🔒 Implement Kubernetes Network Policies
- 🔒 Enable Kubernetes audit logging
- 🔒 Use AWS Systems Manager Session Manager instead of SSH

---

## 💰 Cost Optimization

**Current monthly cost:** ~$35-50

**To reduce:**

- Use t3.micro ($10/month) for development
- Reduce storage from 50GB to 20GB
- Use AWS Compute Savings Plans (1 year = 20% discount)
- Use Reserved Instances (1 year = 40% discount)

---

## 📈 Next Steps After Deployment

1. **Add Users:** Access frontend, create accounts, test messaging
2. **Monitor:** Check CloudWatch logs and Kubernetes metrics
3. **Backup:** Set up automated database backups
4. **Scale:** Increase replicas if needed (`kubectl scale deployment...`)
5. **Update:** Push code changes to repo → GitHub Actions → ArgoCD auto-syncs
6. **Secure:** Add HTTPS, restrict SSH CIDR, implement network policies

---

## 📚 Full Documentation

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design, components, scaling
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Detailed step-by-step guide
- **[terraform/README.md](terraform/README.md)** - Terraform configuration details
- **[ansible/README.md](ansible/README.md)** - Ansible playbook guide
- **[DOCKER_BUILD_GUIDE.md](DOCKER_BUILD_GUIDE.md)** - Docker image building

---

## ✅ Verification Checklist

After deployment, verify these items:

- [ ] EC2 instance running and accessible via SSH
- [ ] MicroK8s cluster status shows "running"
- [ ] All pods in chatapp namespace are "Running" and "Ready"
- [ ] Frontend accessible at http://<EC2_IP>:30080
- [ ] Can create user account and login
- [ ] Real-time messaging works
- [ ] Database persists after pod restart
- [ ] ArgoCD accessible at http://<EC2_IP>:30081
- [ ] GitHub Actions workflow completes successfully
- [ ] ArgoCD shows "Synced" status

---

## 🎉 Success!

When all items above are verified, you have successfully deployed:

```
✅ Production-ready infrastructure on AWS
✅ Kubernetes-orchestrated microservices
✅ Automated CI/CD pipeline
✅ GitOps-style declarative deployments
✅ Persistent database with backup capability
✅ Real-time messaging application
```

**Your ChatApp is running at:** http://<EC2_IP>:30080

**Questions or issues?** Check [docs/DEPLOYMENT.md#troubleshooting](docs/DEPLOYMENT.md#troubleshooting)

---

**Last updated:** 2024  
**Status:** Production Ready ✅
