# Docker Build and Deployment Guide

## Overview

This guide provides exact Docker commands for building, testing, and deploying each ChatApp microservice.

---

## SERVICE 1: BACKEND (Node.js + Express + Socket.IO)

### Build Command

```bash
cd Chat_App/backend
docker build -t chatapp-backend:latest \
  --build-arg PORT=3000 \
  .
```

### Build with Specific Tag (for CI/CD with Git SHA)

```bash
docker build -t $DOCKER_REGISTRY/chatapp-backend:${GIT_SHA} \
  -t $DOCKER_REGISTRY/chatapp-backend:latest \
  --build-arg PORT=3000 \
  Chat_App/backend
```

### Run Locally (Development)

```bash
docker run -d \
  --name chatapp-backend \
  -p 3000:3000 \
  -e MYSQL_HOST=mysql \
  -e MYSQL_USER=chatuser \
  -e MYSQL_PASSWORD=chatpassword \
  -e MYSQL_DATABASE=chat_app \
  -e MYSQL_PORT=3306 \
  -e FRONTEND_URL=http://localhost:5173 \
  -e PORT=3000 \
  --network chatapp-net \
  chatapp-backend:latest
```

### Run Locally (with Local MySQL)

```bash
docker run -d \
  --name chatapp-backend \
  -p 3000:3000 \
  -e MYSQL_HOST=host.docker.internal \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=your_password \
  -e MYSQL_DATABASE=chat_app \
  -e MYSQL_PORT=3306 \
  -e FRONTEND_URL=http://localhost:5173 \
  -e PORT=3000 \
  chatapp-backend:latest
```

### Validation Commands

```bash
# Check if container is running
docker ps | grep chatapp-backend

# Check logs
docker logs chatapp-backend

# Test health endpoint
curl http://localhost:3000/health

# Test API endpoint
curl http://localhost:3000/api/auth/login -X POST

# Interactive shell
docker exec -it chatapp-backend sh
```

### Dockerfile Details

- **Base Image:** node:18-alpine
- **Working Dir:** /app
- **Non-root User:** nodejs (UID 1001)
- **Health Check:** HTTP GET /health every 30s
- **Signal Handling:** dumb-init for proper SIGTERM
- **Security:** Reads only production dependencies

---

## SERVICE 2: FRONTEND (React + Vite)

### Build Command

```bash
cd Chat_App/frontend
docker build -t chatapp-frontend:latest \
  --build-arg VITE_BACKEND_URL=http://localhost:3000 \
  .
```

### Build with Specific Tag (for CI/CD)

```bash
docker build -t $DOCKER_REGISTRY/chatapp-frontend:${GIT_SHA} \
  -t $DOCKER_REGISTRY/chatapp-frontend:latest \
  --build-arg VITE_BACKEND_URL=http://${EXTERNAL_IP}:30080 \
  Chat_App/frontend
```

### Run Locally (Development)

```bash
docker run -d \
  --name chatapp-frontend \
  -p 80:80 \
  -e VITE_BACKEND_URL=http://localhost:3000 \
  --network chatapp-net \
  chatapp-frontend:latest
```

### Run Locally (with specific backend URL)

```bash
docker run -d \
  --name chatapp-frontend \
  -p 80:80 \
  --network chatapp-net \
  chatapp-frontend:latest
```

### Validation Commands

```bash
# Check if container is running
docker ps | grep chatapp-frontend

# Check logs
docker logs chatapp-frontend

# Test health endpoint
curl http://localhost/health

# Test if index.html is served
curl http://localhost/ | head -20

# Check if static assets are loaded
curl -I http://localhost/index.html
```

### Dockerfile Details

- **Base Image:** node:18-alpine (builder) + nginx:alpine (runtime)
- **Build Stage:** Vite build with configurable VITE_BACKEND_URL
- **Runtime:** Lightweight nginx with SPA routing support
- **Non-root User:** nginx (UID 1001)
- **Health Check:** HTTP GET / every 30s
- **Features:** Gzip compression, security headers, cache busting

---

## SERVICE 3: NGINX GATEWAY (Reverse Proxy)

### Build Command

```bash
cd Chat_App/nginx
docker build -t chatapp-nginx:latest .
```

### Build with Tag (for CI/CD)

```bash
docker build -t $DOCKER_REGISTRY/chatapp-nginx:${GIT_SHA} \
  -t $DOCKER_REGISTRY/chatapp-nginx:latest \
  Chat_App/nginx
```

### Run Locally (with Docker Compose network)

```bash
docker run -d \
  --name chatapp-nginx \
  -p 8080:80 \
  --network chatapp-net \
  -v Chat_App/nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  chatapp-nginx:latest
```

### Run Locally (standalone with all networking)

```bash
docker run -d \
  --name chatapp-nginx \
  -p 8080:80 \
  --link chatapp-frontend:frontend \
  --link chatapp-backend:backend \
  chatapp-nginx:latest
```

### Validation Commands

```bash
# Check if container is running
docker ps | grep chatapp-nginx

# Check logs
docker logs chatapp-nginx

# Test health endpoint
curl http://localhost:8080/health

# Test frontend routing
curl http://localhost:8080/ -v

# Test API routing
curl http://localhost:8080/api/auth/login -v

# Check nginx configuration
docker exec chatapp-nginx nginx -t
```

### Dockerfile Details

- **Base Image:** nginx:alpine
- **Configuration:** Custom nginx.conf for routing and WebSocket support
- **Non-root User:** nginx (UID 1001)
- **Health Check:** HTTP GET /health every 30s
- **Features:**
  - Frontend → / proxied to frontend service
  - API → /api/\* proxied to backend service
  - WebSocket → /socket.io upgraded and proxied to backend
  - Long-lived connections with 600s timeout
  - Gzip compression enabled
  - Security headers added

---

## SERVICE 4: MYSQL (Database)

### Build Command

```bash
cd Chat_App/mysql
docker build -t chatapp-mysql:latest .
```

### Build with Tag (for CI/CD)

```bash
docker build -t $DOCKER_REGISTRY/chatapp-mysql:${GIT_SHA} \
  -t $DOCKER_REGISTRY/chatapp-mysql:latest \
  Chat_App/mysql
```

### Run Locally (with persistent volume)

```bash
docker volume create mysql-data

docker run -d \
  --name chatapp-mysql \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=chat_app \
  -e MYSQL_USER=chatuser \
  -e MYSQL_PASSWORD=chatpassword \
  -v mysql-data:/var/lib/mysql \
  --network chatapp-net \
  chatapp-mysql:latest
```

### Run Locally (ephemeral, for testing)

```bash
docker run -d \
  --name chatapp-mysql \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=chat_app \
  -e MYSQL_USER=chatuser \
  -e MYSQL_PASSWORD=chatpassword \
  --network chatapp-net \
  chatapp-mysql:latest
```

### Validation Commands

```bash
# Check if container is running
docker ps | grep chatapp-mysql

# Check logs
docker logs chatapp-mysql

# Test MySQL connection (from host)
mysql -h 127.0.0.1 -u chatuser -pchatpassword chat_app

# Test MySQL connection (from another container)
docker run -it --rm --network chatapp-net \
  mysql:8.0-alpine mysql -h chatapp-mysql -u chatuser -pchatpassword chat_app

# Check database tables
docker exec -it chatapp-mysql mysql -u chatuser -pchatpassword chat_app -e "SHOW TABLES;"

# Check users table structure
docker exec -it chatapp-mysql mysql -u chatuser -pchatpassword chat_app -e "DESC users;"

# Interactive MySQL shell
docker exec -it chatapp-mysql mysql -u root -prootpassword
```

### Dockerfile Details

- **Base Image:** mysql:8.0-alpine
- **Default Database:** chat_app
- **Default User:** chatuser
- **Health Check:** mysqladmin ping every 30s (start-period 30s for DB init)
- **Initialization:** /docker-entrypoint-initdb.d/01-init.sql
- **Configuration:** my.cnf with UTF8mb4, InnoDB tuning, query logging

### Environment Variables

- `MYSQL_ROOT_PASSWORD`: Root password (default: rootpassword)
- `MYSQL_DATABASE`: Database name (default: chat_app)
- `MYSQL_USER`: Regular user (default: chatuser)
- `MYSQL_PASSWORD`: User password (default: chatpassword)

---

## Local Full-Stack Testing with Docker Compose

### docker-compose.yml

```yaml
version: "3.8"

services:
  mysql:
    image: chatapp-mysql:latest
    container_name: chatapp-mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: chat_app
      MYSQL_USER: chatuser
      MYSQL_PASSWORD: chatpassword
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - chatapp-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: chatapp-backend:latest
    container_name: chatapp-backend
    environment:
      PORT: 3000
      MYSQL_HOST: mysql
      MYSQL_USER: chatuser
      MYSQL_PASSWORD: chatpassword
      MYSQL_DATABASE: chat_app
      MYSQL_PORT: 3306
      FRONTEND_URL: http://localhost:8080
    ports:
      - "3000:3000"
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - chatapp-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 5

  frontend:
    image: chatapp-frontend:latest
    container_name: chatapp-frontend
    ports:
      - "80:80"
    networks:
      - chatapp-net
    depends_on:
      - backend
    healthcheck:
      test:
        [
          "CMD",
          "wget",
          "--quiet",
          "--tries=1",
          "--spider",
          "http://localhost/health",
        ]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: chatapp-nginx:latest
    container_name: chatapp-nginx
    ports:
      - "8080:80"
    depends_on:
      - frontend
      - backend
    networks:
      - chatapp-net
    healthcheck:
      test:
        [
          "CMD",
          "wget",
          "--quiet",
          "--tries=1",
          "--spider",
          "http://localhost/health",
        ]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  chatapp-net:
    driver: bridge

volumes:
  mysql-data:
```

### Docker Compose Commands

```bash
# Build all images
docker-compose build

# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f

# Test the full stack
curl http://localhost:8080/health
curl http://localhost:8080/
curl http://localhost:8080/api/auth/login

# Stop all services
docker-compose down

# Clean up volumes
docker-compose down -v
```

---

## Push to Docker Registry

### Login to Docker Hub

```bash
docker login
```

### Build and Push Backend

```bash
docker build -t yourusername/chatapp-backend:${GIT_SHA} Chat_App/backend
docker tag yourusername/chatapp-backend:${GIT_SHA} yourusername/chatapp-backend:latest
docker push yourusername/chatapp-backend:${GIT_SHA}
docker push yourusername/chatapp-backend:latest
```

### Build and Push All Services (Script)

```bash
#!/bin/bash

REGISTRY="yourusername"
GIT_SHA=$(git rev-parse --short HEAD)

services=("backend" "frontend" "nginx" "mysql")

for service in "${services[@]}"; do
  echo "Building and pushing $service..."
  docker build -t $REGISTRY/chatapp-$service:$GIT_SHA -t $REGISTRY/chatapp-$service:latest Chat_App/$service
  docker push $REGISTRY/chatapp-$service:$GIT_SHA
  docker push $REGISTRY/chatapp-$service:latest
done
```

---

## Summary

| Service  | Image            | Port | Volumes        | Health Check    |
| -------- | ---------------- | ---- | -------------- | --------------- |
| Backend  | node:18-alpine   | 3000 | None           | /health HTTP    |
| Frontend | nginx:alpine     | 80   | None           | /health HTTP    |
| Nginx    | nginx:alpine     | 80   | None           | /health HTTP    |
| MySQL    | mysql:8.0-alpine | 3306 | /var/lib/mysql | mysqladmin ping |

All images are production-ready with:

- Non-root users
- Health checks
- Security hardening
- Proper signal handling
- Resource optimization
