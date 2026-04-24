# Ansible Configuration for ChatApp Kubernetes Deployment

This directory contains Ansible playbooks and roles for configuring the EC2 instance with MicroK8s, Docker, kubectl, and ArgoCD.

## Overview

The Ansible configuration automates:

- System package updates and Docker installation
- MicroK8s lightweight Kubernetes cluster setup
- kubectl configuration for local and remote access
- ArgoCD deployment for GitOps workflow
- Namespace and initial configuration setup

## Prerequisites

### Local Machine

1. **Ansible** >= 2.9 installed

   ```bash
   pip install ansible
   ```

2. **Python 3** installed (for module dependencies)

   ```bash
   sudo apt-get install python3 python3-pip
   ```

3. **SSH Key** available locally (same key used in Terraform)

   ```bash
   ls -la ~/.ssh/chatapp-key.pem
   chmod 600 ~/.ssh/chatapp-key.pem
   ```

4. **SSH Access** to EC2 instance
   ```bash
   ssh -i ~/.ssh/chatapp-key.pem ubuntu@<instance-ip>
   ```

### EC2 Instance

- Ubuntu 20.04 LTS or 22.04 LTS
- Public/private IP accessibility
- Port 22 (SSH) open from your machine
- At least 2 vCPU and 4GB RAM (t3.medium recommended)
- 50GB+ disk space

## File Structure

```
ansible/
├── inventory.ini              # Host and variable definitions
├── playbook.yml              # Main orchestration playbook
├── roles/
│   ├── common/
│   │   ├── tasks/main.yml      # System setup & Docker install
│   │   └── handlers/main.yml   # Event handlers
│   ├── microk8s/
│   │   ├── tasks/main.yml      # MicroK8s installation
│   │   └── handlers/main.yml   # K8s event handlers
│   ├── kubectl/
│   │   └── tasks/main.yml      # kubectl configuration
│   └── argocd/
│       ├── tasks/main.yml      # ArgoCD deployment
│       └── files/
│           └── argocd-application.yaml  # App definition
├── .gitignore                # Version control excludes
└── README.md                 # This file
```

## Quick Start

### 1. Update Inventory

```bash
cd ansible
nano inventory.ini
```

Key fields to update:

```ini
[k8s_nodes]
microk8s-primary ansible_host=<YOUR_INSTANCE_IP> \
  ansible_user=ubuntu \
  ansible_ssh_private_key_file=~/.ssh/chatapp-key.pem

[k8s_nodes:vars]
# Update these with your values
docker_registry_username=your-docker-username
docker_registry_password=your-docker-token
argocd_admin_password=your-secure-password
```

### 2. Test Connectivity

```bash
# Test if Ansible can reach the host
ansible all -i inventory.ini -m ping

# Should output:
# <instance-ip> | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

### 3. Run Playbook

```bash
# Dry run (preview changes)
ansible-playbook -i inventory.ini playbook.yml --check

# Actually apply changes
ansible-playbook -i inventory.ini playbook.yml

# Run specific role only
ansible-playbook -i inventory.ini playbook.yml --tags microk8s

# Run with verbose output
ansible-playbook -i inventory.ini playbook.yml -v
ansible-playbook -i inventory.ini playbook.yml -vv  # More verbose
ansible-playbook -i inventory.ini playbook.yml -vvv # Most verbose
```

## Roles Explained

### common

Installs system dependencies and Docker:

- System packages (curl, wget, git, htop, etc.)
- Python3 and pip modules
- Docker CE and containerd
- Docker daemon configuration

**Tags:** `system`, `docker`

### microk8s

Installs and configures MicroK8s Kubernetes:

- Snapd package manager
- MicroK8s snap (lightweight K8s)
- Essential addons (DNS, storage, ingress, cert-manager, argocd)
- kubeconfig setup for ubuntu user
- Cluster verification

**Tags:** `microk8s`, `kubernetes`

### kubectl

Sets up kubectl CLI tool:

- kubectl binary installation
- Bash completion setup
- kubeconfig context configuration
- Helm package manager (optional)
- Cluster access verification

**Tags:** `kubectl`

### argocd

Deploys ArgoCD for GitOps:

- ArgoCD namespace creation
- Helm chart deployment
- Service configuration (NodePort 30081)
- Admin credentials setup
- Application manifest application

**Tags:** `argocd`, `gitops`

## Common Commands

### Ansible Playbook Execution

```bash
# Full deployment
ansible-playbook -i inventory.ini playbook.yml

# Specific role
ansible-playbook -i inventory.ini playbook.yml --tags microk8s

# Skip role
ansible-playbook -i inventory.ini playbook.yml --skip-tags docker

# Specific host
ansible-playbook -i inventory.ini playbook.yml -l microk8s-primary

# Check mode (dry-run)
ansible-playbook -i inventory.ini playbook.yml --check

# Verbose output
ansible-playbook -i inventory.ini playbook.yml -vvv

# Run only handlers
ansible-playbook -i inventory.ini playbook.yml --flush-handlers
```

### Ad-hoc Commands

```bash
# Execute command on all hosts
ansible k8s_nodes -i inventory.ini -m shell -a "microk8s status"

# Copy file to hosts
ansible k8s_nodes -i inventory.ini -m copy -a "src=file.txt dest=/tmp/file.txt"

# Check available facts
ansible k8s_nodes -i inventory.ini -m setup

# Install package
ansible k8s_nodes -i inventory.ini -m apt -a "name=jq state=present" -b

# Service management
ansible k8s_nodes -i inventory.ini -m systemd -a "name=docker state=started" -b
```

### SSH Access

```bash
# Direct SSH
ssh -i ~/.ssh/chatapp-key.pem ubuntu@<instance-ip>

# Through Ansible
ansible k8s_nodes -i inventory.ini -m shell -a "whoami"

# Execute kubectl commands
ansible k8s_nodes -i inventory.ini -m shell -a "/snap/bin/microk8s kubectl get pods"
```

## Verification

After playbook completes, verify deployment:

```bash
# SSH to instance
ssh -i ~/.ssh/chatapp-key.pem ubuntu@<instance-ip>

# Check MicroK8s status
microk8s status

# Check cluster nodes
microk8s kubectl get nodes -o wide

# Check namespaces
microk8s kubectl get namespaces

# Check pods
microk8s kubectl get pods -A

# Check services
microk8s kubectl get svc -A

# ArgoCD access
# URL: http://<instance-ip>:30081
# Username: admin
# Password: (from playbook output or: microk8s kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
```

## Troubleshooting

### SSH Connection Refused

```bash
# Check security group allows port 22
aws ec2 describe-security-groups --group-ids <sg-id> | grep "22"

# Verify SSH service running
ssh -i ~/.ssh/chatapp-key.pem ubuntu@<instance-ip> systemctl status ssh

# Test connectivity
ssh -vvv -i ~/.ssh/chatapp-key.pem ubuntu@<instance-ip>
```

### Ansible Connection Timeout

```bash
# Increase timeout
export ANSIBLE_TIMEOUT=60
ansible-playbook -i inventory.ini playbook.yml

# Or in inventory.ini
ansible_connection_timeout=60
```

### Docker Installation Fails

```bash
# Manually update and retry
ansible k8s_nodes -i inventory.ini -m apt -a "update_cache=yes" -b
ansible-playbook -i inventory.ini playbook.yml --tags docker
```

### MicroK8s Won't Start

```bash
# SSH to instance and check
microk8s status --wait-ready

# If stuck, restart snapd
sudo systemctl restart snapd

# Check snap logs
snap logs microk8s -f
```

### ArgoCD Not Accessible

```bash
# Check if pod is running
kubectl get pods -n argocd

# Check service
kubectl get svc -n argocd

# Check logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Port forward if needed
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

## Security Considerations

1. **Inventory Security**
   - `inventory.ini` contains sensitive data - add to `.gitignore`
   - Use Ansible Vault for passwords:
     ```bash
     ansible-vault encrypt inventory.ini
     ansible-playbook -i inventory.ini playbook.yml --ask-vault-pass
     ```

2. **SSH Key Security**
   - Keep private key in `~/.ssh/` with 600 permissions
   - Use SSH agent to avoid password entry:
     ```bash
     eval $(ssh-agent -s)
     ssh-add ~/.ssh/chatapp-key.pem
     ```

3. **ArgoCD Credentials**
   - Change default admin password immediately
   - Store password in secure vault (1Password, LastPass, etc.)
   - Enable RBAC for production

4. **Firewall Rules**
   - Restrict SSH to your IP in production
   - Restrict K8s NodePort access to necessary IPs

## Advanced Configuration

### Custom Addons

Edit `microk8s_addons` in `inventory.ini`:

```ini
[k8s_nodes:vars]
microk8s_addons=dns,storage,ingress,cert-manager,argocd,registry
```

Available addons:

- dns, storage, ingress, cert-manager, argocd, registry, metrics-server, etc.

### Resource Limits

Modify ArgoCD resources in `roles/argocd/tasks/main.yml`:

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
```

### Node Port Configuration

Change service ports in role tasks (default: 30080-30081)

## Idempotency

All tasks are designed to be idempotent - running the playbook multiple times is safe:

```bash
# First run
ansible-playbook -i inventory.ini playbook.yml

# Second run (no changes should occur)
ansible-playbook -i inventory.ini playbook.yml
```

## Performance Tuning

### Parallel Execution

```bash
ansible-playbook -i inventory.ini playbook.yml -f 10  # Use 10 forks
```

### Fact Caching

Add to ansible.cfg:

```ini
[defaults]
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_cache
fact_caching_timeout = 86400
```

## Documentation Links

- [Ansible Documentation](https://docs.ansible.com/)
- [MicroK8s Documentation](https://microk8s.io/docs)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)

## Support

For issues:

1. Check playbook output for errors
2. Review logs: `cat /var/log/ansible.log`
3. SSH to instance and verify manually
4. Check service status: `systemctl status <service>`
5. Review Ansible debug output: `-vvv` flag
