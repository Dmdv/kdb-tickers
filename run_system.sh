#!/bin/bash

# KDB+ Ticker System Runner
# This script starts all components of the ticker system

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "========================================"
echo "    KDB+ Ticker System Startup"
echo "========================================"

# Check if KDB+ is already running
if pgrep -f "q.*5001" > /dev/null; then
    echo -e "${YELLOW}KDB+ is already running${NC}"
else
    echo -e "${GREEN}Starting KDB+ server...${NC}"
    make kdb-start
    sleep 3
fi

# Check if WebSocket client is already running
if pgrep -f "kdb-ticker-client" > /dev/null; then
    echo -e "${YELLOW}WebSocket client is already running${NC}"
else
    echo -e "${GREEN}Building and starting WebSocket client...${NC}"
    make build
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Starting WebSocket client...${NC}"
        make client &
        CLIENT_PID=$!
        echo "WebSocket client PID: $CLIENT_PID"
    else
        echo -e "${RED}Build failed!${NC}"
        exit 1
    fi
fi

# Wait a moment for everything to start
sleep 5

# Start monitoring
echo -e "\n${GREEN}Starting system monitor...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop all components${NC}\n"

# Run monitor
scripts/monitor.sh

# Cleanup on exit
echo -e "\n${YELLOW}Shutting down...${NC}"
make kdb-stop
pkill -f "kdb-ticker-client"
echo -e "${GREEN}System stopped${NC}" 