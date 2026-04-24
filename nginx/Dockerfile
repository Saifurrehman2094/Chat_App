# Lightweight nginx container for reverse proxy and gateway
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create a non-root user for security
RUN addgroup -g 1001 -S nginx && \
    adduser -S nginx -u 1001

USER nginx

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# Expose port
EXPOSE 80

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
