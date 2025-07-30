#!/bin/bash

# KDB+ Ticker System Monitor
# This script monitors the health of the KDB+ ticker system

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
KDB_HOST=${KDB_HOST:-localhost}
KDB_PORT=${KDB_PORT:-5001}
LOG_FILE="logs/monitor.log"

# Function to check if KDB+ is running
check_kdb_status() {
    if nc -z $KDB_HOST $KDB_PORT 2>/dev/null; then
        echo -e "${GREEN}✓ KDB+ is running on $KDB_HOST:$KDB_PORT${NC}"
        return 0
    else
        echo -e "${RED}✗ KDB+ is not running on $KDB_HOST:$KDB_PORT${NC}"
        return 1
    fi
}

# Function to check WebSocket client
check_websocket_client() {
    if pgrep -f "kdb-ticker-client" > /dev/null; then
        PID=$(pgrep -f "kdb-ticker-client")
        echo -e "${GREEN}✓ WebSocket client is running (PID: $PID)${NC}"
        return 0
    else
        echo -e "${RED}✗ WebSocket client is not running${NC}"
        return 1
    fi
}

# Main monitoring function
main() {
    clear
    echo "========================================"
    echo "    KDB+ Ticker System Monitor"
    echo "========================================"
    echo "Time: $(date)"
    echo ""
    
    # Run checks
    check_kdb_status
    check_websocket_client
    
    echo -e "\n${YELLOW}Press Ctrl+C to exit${NC}"
}

# Handle Ctrl+C
trap 'echo -e "\n${GREEN}Monitoring stopped${NC}"; exit 0' INT

# Run monitoring
if [ "$1" == "--once" ]; then
    main
else
    while true; do
        main
        sleep 10
        clear
    done
fi 