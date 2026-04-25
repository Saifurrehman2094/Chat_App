# MySQL 8.0 container with initialization
FROM mysql:8.0

# Set MySQL root password and configuration
ENV MYSQL_ROOT_PASSWORD=rootpassword \
    MYSQL_DATABASE=chat_app \
    MYSQL_USER=chatuser \
    MYSQL_PASSWORD=chatpassword \
    MYSQL_INITDB_SKIP_TZINFO=1

# MySQL configuration for production-like behavior
COPY ./my.cnf /etc/mysql/conf.d/my.cnf

# Copy initialization script
COPY ./init.sql /docker-entrypoint-initdb.d/01-init.sql

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD mysqladmin ping -h 127.0.0.1 -u $MYSQL_USER -p$MYSQL_PASSWORD --silent

# Expose port
EXPOSE 3306

# Start MySQL
CMD ["mysqld", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci"]
