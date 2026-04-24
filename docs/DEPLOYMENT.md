# ChatApp Automated Deployment - Complete Implementation Guide

**Version:** 1.0  
**Last Updated:** 2024  
**Status:** Production Ready

## Table of Contents

1. [Quick Start (30 minutes)](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Verification Checklist](#verification-checklist)
5. [Troubleshooting](#troubleshooting)
6. [Maintenance](#maintenance)

---

## Quick Start

### Command Sequence (Zero to Working Deployment)

```bash
# ============================================
# 1. LOCAL SETUP (5 min)
# ============================================
cd Chat_App

# Clone and enter repo
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
# Update: aws_region, key_pair_name, instance_type, allowed_ssh_cidrs

# ============================================
# 2. INFRASTRUCTURE PROVISIONING (10 min)
# ============================================

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Save outputs
terraform output -json > ../infrastructure-outputs.json
EC2_IP=$(terraform output -raw instance_public_ip)
echo "Instance IP: $EC2_IP"

# ============================================
# 3. CONFIGURATION MANAGEMENT (10 min)
# ============================================

cd ../ansible

# Update inventory with EC2 IP
sed -i "s/<INSTANCE_PUBLIC_IP>/$EC2_IP/g" inventory.ini

# Test connection
ansible all -i inventory.ini -m ping

# Run playbook (wait ~3-5 minutes)
ansible-playbook -i inventory.ini playbook.yml

# Get kubeconfig
ansible k8s_nodes -i inventory.ini -m fetch \
  -a "src=/home/ubuntu/.kube/config dest=./kubeconfig_$EC2_IP flat=yes"

# ============================================
# 4. APPLICATION DEPLOYMENT (5 min)
# ============================================

cd ../k8s

# Deploy ChatApp to cluster
/snap/bin/microk8s kubectl apply -k .

# Verify deployment (wait for pods to be ready)
/snap/bin/microk8s kubectl get pods -n chatapp -w

# ============================================
# 5. VERIFY & ACCESS
# ============================================

# Check all services
/snap/bin/microk8s kubectl get svc -n chatapp

# Frontend should be accessible at:
echo "http://$EC2_IP:30080"

# Get ArgoCD admin password
ARGOCD_PASS=$(/snap/bin/microk8s kubectl get secret -n argocd \
  argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "ArgoCD at: http://$EC2_IP:30081"
echo "Username: admin"
echo "Password: $ARGOCD_PASS"
```

---

## Prerequisites

### Required Software (Local Machine)

```bash
# macOS
brew install terraform ansible aws-cli

# Ubuntu/Debian
sudo apt-get install terraform ansible awscli

# Verify installations
terraform version          # >= 1.0
ansible --version          # >= 2.9
aws --version              # >= 2.0
```

### AWS Setup

```bash
# 1. Create SSH key pair
aws ec2 create-key-pair --key-name chatapp-key --region us-east-1 \
  --query 'KeyMaterial' --output text > ~/.ssh/chatapp-key.pem
chmod 600 ~/.ssh/chatapp-key.pem

# 2. Configure AWS CLI
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Format (json)

# 3. Verify credentials
aws sts get-caller-identity
```

### Docker Hub Setup

```bash
# Create Docker Hub account at https://hub.docker.com
# Create personal access token

# Login locally
docker login -u your_username -p your_token

# Configure GitHub secrets (see CI/CD section)
```

### GitHub Setup

1. Fork or clone the Chat_App repository
2. Generate personal access token (Settings → Developer settings → Personal access tokens)
3. Add repository secrets (Settings → Secrets and variables → Actions):
   - `DOCKER_USERNAME`: Docker Hub username
   - `DOCKER_PASSWORD`: Docker Hub personal access token
   - `EC2_INSTANCE_IP`: EC2 instance public IP (after Terraform)

---

## Step-by-Step Deployment

### Phase 1: Infrastructure Provisioning (Terraform)

**Duration:** ~10 minutes  
**Goal:** Create VPC, EC2 instance, security groups, monitoring

```bash
cd terraform

# Step 1: Initialize
terraform init

# Step 2: Validate
terraform validate
terraform fmt -check .

# Step 3: Plan
terraform plan -out=tfplan

# Expected output: ~20 resources to be created (VPC, subnet, IGW, SG, EC2, etc.)

# Step 4: Apply
terraform apply tfplan

# Step 5: Save outputs
terraform output instance_public_ip
terraform output -json > deployment-info.json

# Step 6: Verify EC2 is running
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].State'

# Step 7: Wait for instance ready (user-data to complete)
sleep 60
ssh -i ~/.ssh/chatapp-key.pem ubuntu@<instance-ip> \
  "tail /var/log/user-data.log"
```

**Next:** EC2 instance is ready when user-data script completes (check logs)

---

### Phase 2: Configuration Management (Ansible)

**Duration:** ~5-8 minutes  
**Goal:** Install Docker, MicroK8s, kubectl, ArgoCD

```bash
cd ansible

# Step 1: Update inventory with EC2 IP
nano inventory.ini
# Update: ansible_host=<YOUR_EC2_IP>

# Step 2: Test connectivity
ansible all -i inventory.ini -m ping
# Expected: pong response from EC2

# Step 3: Run playbook
ansible-playbook -i inventory.ini playbook.yml

# This will:
# - Install Docker and dependencies
# - Install MicroK8s via snap
# - Enable K8s addons (DNS, storage, cert-manager, ArgoCD)
# - Install kubectl
# - Deploy ArgoCD

# Step 4: Verify completion
ansible k8s_nodes -i inventory.ini -m shell \
  -a "/snap/bin/microk8s status"

# Step 5: Retrieve kubeconfig
ansible k8s_nodes -i inventory.ini -m fetch \
  -a "src=/home/ubuntu/.kube/config dest=./kubeconfig flat=yes"

# Step 6: Save kubeconfig locally
export KUBECONFIG=./kubeconfig
kubectl cluster-info
```

**Next:** MicroK8s cluster is ready when all addons are enabled

---

### Phase 3: Kubernetes Deployment

**Duration:** ~3 minutes  
**Goal:** Deploy ChatApp services (MySQL, Backend, Frontend, Nginx)

```bash
cd k8s

# Step 1: Create secrets (IMPORTANT!)
kubectl create secret generic mysql-credentials \
  --from-literal=mysql-root-password=rootpassword \
  --from-literal=mysql-user=chatuser \
  --from-literal=mysql-password=chatpassword \
  -n chatapp

kubectl create secret generic backend-secrets \
  --from-literal=JWT_SECRET=your-secret-jwt-key \
  --from-literal=FRONTEND_URL=http://<EC2_IP>:30080 \
  -n chatapp

# Step 2: Build and push Docker images (if not using pre-built)
# Skip if using images from previous CI/CD builds

# Step 3: Apply manifests
kubectl apply -k .

# This deploys:
# - MySQL (with PVC)
# - Backend (2 replicas)
# - Frontend (2 replicas)
# - Nginx Gateway (NodePort 30080)

# Step 4: Monitor deployments
kubectl get deployments -n chatapp
kubectl get pods -n chatapp

# Wait for all pods to be Ready
kubectl wait --for=condition=ready pod \
  -l app=chatapp -n chatapp --timeout=300s

# Step 5: Verify services
kubectl get svc -n chatapp -o wide

# Step 6: Test endpoints
curl http://<EC2_IP>:30080/health
curl http://<EC2_IP>:30080/
```

**Next:** All pods should be Running and Ready

---

### Phase 4: GitOps Setup (ArgoCD)

**Duration:** ~2 minutes  
**Goal:** Configure ArgoCD to auto-sync manifests

```bash
# Step 1: Access ArgoCD
ARGOCD_IP=<EC2_IP>
ARGOCD_PASS=$(kubectl get secret -n argocd \
  argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

# Access at: http://$ARGOCD_IP:30081
# Username: admin
# Password: $ARGOCD_PASS

# Step 2: Connect repository
# In ArgoCD UI:
# 1. Go to Settings → Repositories → Connect Repo
# 2. Choose GitHub
# 3. Paste repo URL: https://github.com/<username>/Chat_App
# 4. Generate access token (optional, for private repos)

# Step 3: Create ArgoCD Application
kubectl apply -f ../argocd/application.yaml

# Step 4: Verify application sync
kubectl get application -n argocd
kubectl describe application chatapp -n argocd

# Step 5: Monitor sync status
watch kubectl get application chatapp -n argocd
```

**Next:** ArgoCD should show "Synced" status in ~30 seconds

---

## Verification Checklist

### ✅ Infrastructure Health

```bash
# VPC and networking
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=chatapp-vpc"

# EC2 instance
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]'

# Security group
aws ec2 describe-security-groups --group-names chatapp-sg

# Expected: VPC active, EC2 running, security groups configured
```

### ✅ Cluster Health

```bash
# Cluster status
/snap/bin/microk8s status

# Nodes
kubectl get nodes -o wide

# Expected: 1 node in Ready state
```

### ✅ Pod Readiness

```bash
# All pods
kubectl get pods -A

# ChatApp namespace
kubectl get pods -n chatapp

# Expected: All pods Running and Ready (2/2 or 1/1)
```

### ✅ Frontend Accessible

```bash
# HTTP request
curl -I http://<EC2_IP>:30080/

# Expected: HTTP 200 OK

# In browser:
# http://<EC2_IP>:30080
```

### ✅ API Working

```bash
# Health check
curl http://<EC2_IP>:30080/api/health

# Login endpoint
curl -X POST http://<EC2_IP>:30080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}'

# Expected: 200 OK or 401 Unauthorized (missing credentials is OK)
```

### ✅ WebSocket Messaging

```bash
# Connect to backend
curl -I -N -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://<EC2_IP>:30080/socket.io/?transport=websocket

# Expected: 101 Switching Protocols
```

### ✅ Database Persistence

```bash
# Check PVC
kubectl get pvc -n chatapp

# Expected: mysql-pvc Bound

# Verify data
kubectl exec -it deployment/mysql -n chatapp -- \
  mysql -u chatuser -pchatpassword chat_app -e "SHOW TABLES;"

# Expected: users, chats, messages, chat_users tables exist
```

### ✅ CI/CD Pipeline Working

```bash
# 1. Make a test change to backend or frontend
git checkout -b test-change
echo "// test" >> backend/server.js
git add backend/server.js
git commit -m "test: verify CI/CD"
git push origin test-change

# 2. Create pull request
# 3. Check GitHub Actions workflow runs

# Expected:
# - Docker images build successfully
# - Manifests updated with new image tags
# - Changes committed back to repo
```

---

## Troubleshooting

### Common Issues & Solutions

#### SSH Connection Timeout

**Symptom:** `ssh: connect to host timeout`

**Diagnostic:**

```bash
# 1. Verify security group allows SSH
aws ec2 describe-security-groups --group-ids <sg-id> \
  --query 'SecurityGroupRules[?FromPort==`22`]'

# 2. Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id>

# 3. Test connectivity
nc -zv <public-ip> 22
```

**Fix:**

```bash
# Add your IP to security group
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp --port 22 --cidr YOUR_IP/32
```

---

#### Ansible Playbook Fails

**Symptom:** `FAILED - fatal: [instance]: ...`

**Diagnostic:**

```bash
# Run with verbose output
ansible-playbook -i inventory.ini playbook.yml -vvv

# SSH to instance and check manually
ssh -i ~/.ssh/chatapp-key.pem ubuntu@<instance-ip>
microk8s status
systemctl status docker
```

**Fix:**

```bash
# Common causes:
# 1. User-data script not complete - wait 2-3 minutes
sleep 180
ansible-playbook -i inventory.ini playbook.yml

# 2. Snapd issues - restart
ansible k8s_nodes -i inventory.ini -m systemd \
  -a "name=snapd state=restarted" -b

# 3. Network issues - retry with patience
ansible-playbook -i inventory.ini playbook.yml --retries 5
```

---

#### Pods Stuck in Pending

**Symptom:** `kubectl get pods -n chatapp` shows Pending status

**Diagnostic:**

```bash
# Check pod events
kubectl describe pod <pod-name> -n chatapp

# Check node resources
kubectl top nodes

# Check PVC status
kubectl get pvc -n chatapp
```

**Fix:**

```bash
# 1. Recreate PVC if stuck
kubectl delete pvc mysql-pvc -n chatapp
kubectl apply -f k8s/mysql/pvc.yaml

# 2. Increase node resources (t3.medium → t3.large)
# Requires terminating and recreating instance

# 3. Check image availability
kubectl describe pod backend-xxx -n chatapp | grep Image
```

---

#### Frontend Shows 404 or Blank Page

**Symptom:** Browser shows error or empty page

**Diagnostic:**

```bash
# Check frontend pod logs
kubectl logs deployment/frontend -n chatapp

# Check nginx gateway logs
kubectl logs deployment/nginx-gateway -n chatapp

# Test direct backend URL
curl http://<EC2_IP>:30080/api/auth/login
```

**Fix:**

```bash
# 1. Verify environment variable is set
kubectl get deployment frontend -n chatapp -o yaml | grep VITE_BACKEND_URL

# 2. Rebuild frontend with correct backend URL
docker build --build-arg VITE_BACKEND_URL=http://<EC2_IP>:30080 \
  -t chatapp-frontend:latest frontend/

# 3. Update manifest and re-apply
kubectl set image deployment/frontend \
  frontend=<new-image>:<tag> -n chatapp
```

---

#### MySQL Connection Refused

**Symptom:** Backend logs: `Error: connect ECONNREFUSED 127.0.0.1:3306`

**Diagnostic:**

```bash
# Check MySQL pod
kubectl get pods -n chatapp -l app=mysql

# Check MySQL logs
kubectl logs deployment/mysql -n chatapp

# Test MySQL connection from backend pod
kubectl exec -it deployment/backend -n chatapp -- \
  mysql -h mysql.chatapp.svc.cluster.local -u chatuser -pchatpassword chat_app -e "SHOW TABLES;"
```

**Fix:**

```bash
# 1. Verify MySQL_HOST env var
kubectl get deployment backend -n chatapp -o yaml | grep MYSQL_HOST

# Should be: mysql.chatapp.svc.cluster.local

# 2. Verify credentials match
kubectl get secret mysql-credentials -n chatapp -o yaml

# 3. Restart MySQL
kubectl delete pod -l app=mysql -n chatapp
```

---

#### ArgoCD Not Syncing

**Symptom:** ArgoCD Application shows "OutOfSync"

**Diagnostic:**

```bash
# Check application status
kubectl get application chatapp -n argocd -o yaml

# Check sync errors
kubectl describe application chatapp -n argocd | grep -A 5 "Status:"

# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Fix:**

```bash
# 1. Manually trigger sync
argocd app sync chatapp

# 2. Or via kubectl
kubectl patch application chatapp -n argocd -p \
  '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge

# 3. Check git credentials if private repo
kubectl get secret argocd-repo-creds-* -n argocd -o yaml
```

---

## Maintenance

### Regular Tasks

#### Weekly

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running

# Review logs
kubectl logs -n chatapp --tail=100 --timestamps=true
```

#### Monthly

```bash
# Update kubeconfig
ansible k8s_nodes -i ansible/inventory.ini -m fetch \
  -a "src=/home/ubuntu/.kube/config dest=./kubeconfig flat=yes"

# Backup database
kubectl exec -it deployment/mysql -n chatapp -- \
  mysqldump -u root -p<password> chat_app > backup-$(date +%Y%m%d).sql

# Check available updates
snap refresh --dry-run
```

#### Quarterly

```bash
# Update Kubernetes
/snap/bin/microk8s refresh

# Review security
aws accessanalyzer validate-policy ...

# Audit access logs
aws s3 ls s3://chatapp-logs/
```

### Scaling

#### Horizontal Pod Scaling

```bash
# Manual scaling
kubectl scale deployment backend --replicas=3 -n chatapp

# Horizontal Pod Autoscaler (configured in k8s/nginx/deployment.yaml)
kubectl get hpa -n chatapp
```

#### Vertical Scaling (Increase EC2 instance size)

```bash
# Terminate current instance
terraform destroy

# Update terraform.tfvars
# instance_type = "t3.large"

# Reapply
terraform apply

# Re-run Ansible playbook
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

### Backup & Disaster Recovery

```bash
# Backup entire cluster
kubectl get all -A -o yaml > cluster-backup-$(date +%Y%m%d).yaml

# Backup PVC (database)
kubectl exec deployment/mysql -n chatapp -- \
  mysqldump -u root -p<password> --all-databases > full-backup-$(date +%Y%m%d).sql

# Save Terraform state
aws s3 cp terraform.tfstate s3://chatapp-backups/
```

---

## Support & Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Ansible Documentation](https://docs.ansible.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [MicroK8s](https://microk8s.io/docs/)
- [ArgoCD](https://argo-cd.readthedocs.io/)

---

## Success Indicators

You have successfully deployed ChatApp when:

✅ Frontend accessible at `http://<EC2_IP>:30080`  
✅ Users can create accounts and login  
✅ Real-time messaging works via WebSocket  
✅ All pods are Running and Ready  
✅ ArgoCD shows "Synced" status  
✅ Database contains persisted data after pod restart  
✅ CI/CD pipeline automatically updates images on git push

**Congratulations! 🎉 Your ChatApp is deployed!**
