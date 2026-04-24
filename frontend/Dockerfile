# Multi-stage build for frontend
# Stage 1: Builder
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
# NOTE: VITE_BACKEND_URL will be injected at build time via build arg or env var
ARG VITE_BACKEND_URL=http://localhost:3000
ENV VITE_BACKEND_URL=$VITE_BACKEND_URL

RUN npm run build

# Stage 2: Runtime (lightweight nginx server)
FROM nginx:alpine

# Copy nginx config for SPA routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built app from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Create a non-root user
RUN addgroup -g 1001 -S nginx && \
    adduser -S nginx -u 1001

USER nginx

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
