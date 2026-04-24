# ChatApp Architecture & Infrastructure Design

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       AWS Account (us-east-1)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ VPC (10.0.0.0/16) with Public Subnet (10.0.1.0/24)       │   │
│  │                                                           │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │ EC2 Instance: t3.medium (2 vCPU, 4GB RAM)         │  │   │
│  │  │ OS: Ubuntu 22.04 LTS                              │  │   │
│  │  │ Public IP: x.x.x.x (Elastic IP optional)          │  │   │
│  │  │                                                    │  │   │
│  │  │  ┌──────────────────────────────────────────────┐ │  │   │
│  │  │  │ MicroK8s Cluster                            │ │  │   │
│  │  │  │                                              │ │  │   │
│  │  │  │  ┌────────────────────────────────────────┐ │ │  │   │
│  │  │  │  │ chatapp namespace                      │ │ │  │   │
│  │  │  │  ├────────────────────────────────────────┤ │ │  │   │
│  │  │  │  │                                        │ │ │  │   │
│  │  │  │  │  ┌──────────────┐  ┌──────────────┐  │ │ │  │   │
│  │  │  │  │  │ Frontend Pod │  │ Backend Pod  │  │ │ │  │   │
│  │  │  │  │  │ (2 replicas) │  │ (2 replicas) │  │ │ │  │   │
│  │  │  │  │  │ nginx server │  │ Express.js   │  │ │ │  │   │
│  │  │  │  │  └──────────────┘  │ Socket.IO    │  │ │ │  │   │
│  │  │  │  │                    └──────────────┘  │ │ │  │   │
│  │  │  │  │                                        │ │ │  │   │
│  │  │  │  │  ┌──────────────┐  ┌──────────────┐  │ │ │  │   │
│  │  │  │  │  │ Nginx Gateway│  │ MySQL Pod    │  │ │ │  │   │
│  │  │  │  │  │ (reverse     │  │ (1 replica)  │  │ │ │  │   │
│  │  │  │  │  │ proxy)       │  │ w/ PVC       │  │ │ │  │   │
│  │  │  │  │  └──────────────┘  └──────────────┘  │ │ │  │   │
│  │  │  │  │                                        │ │ │  │   │
│  │  │  │  │ ┌────────────────────────────────────┐│ │ │  │   │
│  │  │  │  │ │ argocd namespace (GitOps)         ││ │ │  │   │
│  │  │  │  │ │ - ArgoCD server                   ││ │ │  │   │
│  │  │  │  │ │ - ArgoCD controller               ││ │ │  │   │
│  │  │  │  │ │ - ArgoCD repo-server              ││ │ │  │   │
│  │  │  │  │ └────────────────────────────────────┘│ │ │  │   │
│  │  │  │  └────────────────────────────────────────┘ │ │  │   │
│  │  │  │  Services:                                   │ │  │   │
│  │  │  │  - NodePort 30080 (HTTP) → Nginx Gateway    │ │  │   │
│  │  │  │  - NodePort 30443 (HTTPS ready)            │ │  │   │
│  │  │  │  - NodePort 30081 (ArgoCD)                 │ │  │   │
│  │  │  │  - ClusterIP (Internal DNS)                │ │  │   │
│  │  │  │                                              │ │  │   │
│  │  │  └──────────────────────────────────────────────┘ │  │   │
│  │  │ Storage: PVC (microk8s-hostpath) → /var/lib/mysql   │  │   │
│  │  │ Networking: iptables, kube-proxy, CoreDNS          │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  │                                                           │   │
│  │ Internet Gateway                                          │   │
│  │ Security Group: SSH(22), HTTP(30080), HTTPS(30443), etc  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

         ↓ GitHub Push
    CI/CD Pipeline (GitHub Actions)
    - Build Docker images
    - Push to Docker Hub
    - Update k8s manifests
    - Commit back to repo

         ↓ Repository Updates
    ArgoCD (Watches for Changes)
    - Detects manifest updates
    - Auto-syncs to cluster
    - Reports deployment status

External Users:
    Browser → http://x.x.x.x:30080 → Nginx Gateway → Frontend + Backend
```

## Service Communication Flow

### User Browser to Application

```
1. User opens browser: http://x.x.x.x:30080
   ↓
2. Nginx Gateway (NodePort 30080)
   ├─ GET / → Routes to Frontend Service
   ├─ GET /api/* → Routes to Backend Service
   └─ WS /socket.io → WebSocket upgrade to Backend Service
   ↓
3. Frontend Service (ClusterIP) → Frontend Pod (nginx)
   - Serves React SPA (index.html, JavaScript bundles)
   - Configured to redirect API calls to /api and WebSocket to /socket.io
   ↓
4. Backend Service (ClusterIP) → Backend Pod (Node.js)
   - Processes HTTP requests (REST API)
   - Handles WebSocket connections (Socket.IO)
   ↓
5. Backend Pod connects to MySQL Service (ClusterIP)
   - DNS: mysql.chatapp.svc.cluster.local:3306
   - Queries database for user, chat, message data
```

### Data Flow

```
Frontend ← HTTPS/HTTP → Nginx Gateway ← HTTP → Backend ← MySQL
  (SPA)      (30080)       (reverse proxy)    (Express)   (TCP 3306)
   React                     Routing rules      Node.js    Sequelize ORM
   Vite                      WebSocket upgrade  Socket.IO  UTF8mb4
  dist/                       Long timeouts     JWT Auth   InnoDB
  Static assets
```

## Component Details

### Frontend (React + Vite)

**Container:** chatapp-frontend  
**Base Image:** nginx:alpine  
**Port:** 80 (internal) → 30080 (external via Nginx Gateway)  
**Resources:** 50m CPU, 64Mi RAM (requests) / 100m, 128Mi (limits)  
**Replicas:** 2 (for availability)

**Deployment Pattern:**

- Multi-stage Docker build (builder → runtime)
- Vite compiles React to static HTML/JS
- nginx serves static files with SPA routing (index.html fallback)
- Health check: GET /health

**Communication:**

- Makes API calls to http://localhost:30080/api/\* (same domain as gateway)
- Establishes WebSocket at ws://localhost:30080/socket.io

---

### Backend (Node.js + Express + Socket.IO)

**Container:** chatapp-backend  
**Base Image:** node:18-alpine  
**Port:** 3000 (internal) → accessed via Backend Service  
**Resources:** 100m CPU, 128Mi RAM (requests) / 200m, 256Mi (limits)  
**Replicas:** 2 (for availability, sticky sessions via Service)

**Features:**

- Express.js REST API (`/api/auth`, `/api/user`, `/api/chat`, `/api/message`)
- Socket.IO for real-time bidirectional communication
- JWT authentication
- CORS configured to Frontend URL
- Connection pooling to MySQL

**Environment Variables:**

- MYSQL_HOST: mysql.chatapp.svc.cluster.local (K8s service DNS)
- MYSQL_PORT: 3306
- MYSQL_USER/PASSWORD: From Secret
- FRONTEND_URL: For CORS
- JWT_SECRET: From Secret

**Health Check:** GET /health (returns 200 OK)

---

### Database (MySQL 8.0)

**Container:** chatapp-mysql  
**Base Image:** mysql:8.0-alpine  
**Port:** 3306 (ClusterIP service)  
**Storage:** PVC 10Gi (microk8s-hostpath → /var/lib/mysql)  
**Replicas:** 1 (single instance, can upgrade to StatefulSet for HA)  
**Resources:** 250m CPU, 256Mi RAM (requests) / 500m, 512Mi (limits)

**Database Schema:**

- users (authentication, profiles)
- chats (group/1-1 conversations)
- messages (chat messages)
- chat_users (many-to-many relationship)

**Initialization:** init.sql (creates database and schema)  
**Character Set:** utf8mb4 (supports emojis)  
**Collation:** utf8mb4_unicode_ci  
**Health Check:** mysqladmin ping

---

### Nginx Gateway (Reverse Proxy)

**Container:** chatapp-nginx  
**Base Image:** nginx:alpine  
**Port:** 80 (internal) → 30080/30443 (NodePort external)  
**Resources:** 100m CPU, 128Mi RAM (requests) / 200m, 256Mi (limits)  
**Replicas:** 1 (can scale with HPA for high traffic)

**Routing Rules:**

```
GET  /           → Frontend Service:80
GET  /api/*      → Backend Service:3000
WS   /socket.io  → Backend Service:3000 (Upgrade headers)
```

**Features:**

- Gzip compression for faster delivery
- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Long timeouts for WebSocket (600s, 86400s for socket.io)
- Session affinity (ClientIP) for WebSocket persistence
- HTTP/1.1 keep-alive
- Proxy buffering configuration

---

## Network Topology

### Internal (Cluster)

```
Pod-to-Pod: Direct via CNI (Container Network Interface)
Pod-to-Service: DNS resolution (e.g., mysql.chatapp.svc.cluster.local)
Service-to-Pod: Load balancing (round-robin default)

DNS: CoreDNS (kube-system namespace)
Network Policy: Can be added for zero-trust network
```

### External (EC2 to Internet)

```
Internet ← IGW (Internet Gateway) ← Route Table ← VPC
        ↓
    Nginx Gateway Pod
    NodePort 30080
    ↓
    EC2 Instance
    Public IP (Elastic IP optional)
    Security Group: Allow 30080, 30443, SSH
```

## Storage Architecture

### MySQL Data Persistence

```
┌─────────────────────────────────┐
│ Kubernetes PVC (mysql-pvc)      │
│ Size: 10Gi                      │
│ Access Mode: ReadWriteOnce      │
│ Storage Class: microk8s-hostpath│
└────────────┬────────────────────┘
             ↓
┌─────────────────────────────────┐
│ Host Local Storage (/var/lib/mysql on EC2)
│ Mounted into MySQL Pod          │
│ Data survives pod restart       │
└─────────────────────────────────┘
```

**For Production HA:**

- Use AWS EBS volumes instead of hostpath
- Configure StatefulSet with EBS CSI driver
- Implement database replication

## Security Architecture

### Network Security

```
Security Group:
├─ Inbound SSH (22): Limited IPs
├─ Inbound HTTP (30080): 0.0.0.0/0
├─ Inbound HTTPS (30443): 0.0.0.0/0
├─ Inbound NodePort (30000-32767): 0.0.0.0/0
├─ Internal traffic (10.0.0.0/16): All allowed
└─ Egress: All protocols to 0.0.0.0/0

Network ACL:
├─ Inbound SSH, HTTP, HTTPS, NodePorts allowed
├─ Ephemeral ports (1024-65535) allowed for responses
└─ All outbound allowed
```

### Pod Security

```
Container Security Context:
├─ RunAsNonRoot: true (no root privilege)
├─ AllowPrivilegeEscalation: false
├─ ReadOnlyRootFilesystem: false (can be true for some)
├─ Capabilities: Drop ALL, add NET_BIND_SERVICE if needed
└─ SELinux: Enforced if available

Secrets Management:
├─ MySQL credentials (from K8s Secret)
├─ JWT secret (from K8s Secret)
├─ Registry credentials (from K8s Secret)
└─ Sealed Secrets recommended for git-friendly encryption
```

### API Security

```
Authentication: JWT (from Backend)
  - Issued on login
  - Validated on each request
  - Secret stored in K8s Secret

Authorization: Backend validates user permissions
  - Per-API endpoint
  - Role-based (can implement)

Communication:
  - Backend ← Frontend: Same origin (no CORS needed internally)
  - Frontend ← External: CORS headers configured
  - HTTPS ready (30443 NodePort, certificates via cert-manager)
```

## Scalability Architecture

### Horizontal Pod Autoscaling (HPA)

```
Nginx Gateway HPA:
├─ Min replicas: 1
├─ Max replicas: 3
├─ CPU trigger: 70% utilization
└─ Memory trigger: 80% utilization

Backend/Frontend: Manual scaling or additional HPA configs
```

### Vertical Scaling

```
Current:
├─ EC2 instance: t3.medium (2 vCPU, 4GB RAM)
├─ Pod limits: Configured to fit within instance

Scaling Options:
├─ Upgrade EC2: t3.large, t3.xlarge (requires downtime)
├─ Add more nodes: MicroK8s single-node (requires multi-node setup)
└─ Optimize pod resources: Right-size requests/limits
```

## High Availability Considerations

### Current (Single Node)

```
Single Point of Failure: EC2 instance
Recovery: Terraform destroy → apply (manual)
RTO (Recovery Time Objective): ~15 minutes
RPO (Recovery Point Objective): Last database backup
```

### Production Recommendations

```
Multi-Zone HA:
├─ Multiple EC2 instances (one per AZ)
├─ MicroK8s in multi-node mode
├─ Shared storage (AWS EFS or S3)
└─ RTO < 5 minutes

Database HA:
├─ MySQL replication (primary-secondary)
├─ Read replicas for scaling
├─ Automated failover
└─ RPO < 1 minute

Load Balancing:
├─ AWS Network Load Balancer (NLB) for EC2 instances
├─ Health checks on 30080/health
├─ Distribute traffic across nodes
└─ Sticky sessions for WebSocket
```

## Monitoring & Observability

### Metrics Collection

```
Prometheus (optional addon):
├─ Pod CPU/memory usage
├─ Node metrics
├─ Custom application metrics
└─ Alerting rules

Dashboard: Grafana (optional addon)
├─ Cluster health
├─ Pod resource utilization
└─ Application performance
```

### Logging

```
Container Logs:
├─ Docker logs: docker logs <container>
├─ Kubernetes logs: kubectl logs <pod>
├─ Persistent: /var/log/* on EC2

Log Aggregation Options:
├─ ELK Stack (Elasticsearch, Logstash, Kibana)
├─ AWS CloudWatch Logs
└─ Datadog, New Relic, Splunk
```

### Health Checks

```
Liveness Probe: Pod alive?
├─ Backend: GET /health (HTTP)
├─ Frontend: GET /health (HTTP)
├─ MySQL: mysqladmin ping

Readiness Probe: Pod ready for traffic?
├─ Backend: GET /health (HTTP) - more frequent
├─ Frontend: GET / (HTTP)
├─ MySQL: mysqladmin ping
```

## Disaster Recovery

### Backup Strategy

```
Database:
├─ mysqldump daily to S3
├─ Retention: 30 days rolling
└─ Test restore weekly

State:
├─ Terraform state to S3 + DynamoDB lock
├─ Git repository (immutable history)
└─ Kubernetes manifests (version controlled)

Configuration:
├─ ConfigMaps backed up
├─ Secrets encrypted in K8s (or sealed-secrets)
└─ Documented procedures
```

### Recovery Procedures

```
Pod Failure:
├─ Automatic restart by Kubernetes
├─ Expected downtime: < 30 seconds
└─ Data persists in PVC

Node Failure:
├─ Pods rescheduled to other nodes (N/A for single-node currently)
├─ Expected downtime: 2-5 minutes
└─ Data persists in PVC

Data Corruption:
├─ Restore from latest database backup
├─ Expected downtime: 10-30 minutes
└─ Data loss: Up to 24 hours (based on backup frequency)
```

---

## Summary

**ChatApp is architected for:**

- ✅ **Ease of Deployment:** Terraform IaC, Ansible configuration, Kubernetes manifests
- ✅ **Scalability:** Horizontal scaling with HPA, vertical scaling available
- ✅ **High Availability:** Multi-replica services, persistent storage, health checks
- ✅ **Security:** Non-root containers, network policies, secrets management
- ✅ **Observability:** Built-in health checks, logging, metrics-ready
- ✅ **GitOps:** ArgoCD for declarative, version-controlled deployments
- ✅ **CI/CD:** Automated builds, testing, image updates, manifest synchronization
