#!/bin/bash

# KDB+ Ticker System Docker Entrypoint

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}Starting KDB+ Ticker System${NC}"
echo "Symbol: ${SYMBOL}"
echo "KDB Host: ${KDB_HOST}"
echo "KDB Port: ${KDB_PORT}"

# Ensure directories exist with correct permissions
mkdir -p /app/data /app/logs /app/archive
chown -R kdb:kdb /app/data /app/logs /app/archive

# Wait for any dependent services (if running in docker-compose)
if [ ! -z "$WAIT_FOR_SERVICES" ]; then
    echo -e "${YELLOW}Waiting for dependent services...${NC}"
    for service in $WAIT_FOR_SERVICES; do
        host=$(echo $service | cut -d: -f1)
        port=$(echo $service | cut -d: -f2)
        echo "Waiting for $host:$port..."
        while ! nc -z $host $port; do
            sleep 1
        done
        echo "$host:$port is available"
    done
fi

# If running with external KDB+, don't start local server
if [ "$KDB_HOST" != "localhost" ] && [ "$KDB_HOST" != "127.0.0.1" ]; then
    echo -e "${YELLOW}Using external KDB+ server at $KDB_HOST:$KDB_PORT${NC}"
    # Disable kdb-server in supervisor
    cat > /tmp/supervisord.conf << EOF
[supervisord]
nodaemon=true
user=root
logfile=/app/logs/supervisord.log

[program:kdb-client]
command=/app/kdb-ticker-client
directory=/app
autostart=true
autorestart=true
stdout_logfile=/app/logs/kdb-client.log
stderr_logfile=/app/logs/kdb-client-error.log
environment=RUST_LOG="${RUST_LOG}",KDB_HOST="${KDB_HOST}",KDB_PORT="${KDB_PORT}",SYMBOL="${SYMBOL}"
user=kdb
EOF
    exec supervisord -c /tmp/supervisord.conf
fi

# Execute the command
exec "$@" 