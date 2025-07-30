#!/bin/bash

# Multi-Symbol Deployment Script for KDB+ Ticker System

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default config file
CONFIG_FILE="${1:-../config/symbols.conf}"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}KDB+ Multi-Symbol Deployment${NC}"
echo -e "${BLUE}=============================${NC}"
echo ""

# Function to parse priority to systemd CPUWeight
get_cpu_weight() {
    case $1 in
        high) echo "200";;
        medium) echo "100";;
        low) echo "50";;
        *) echo "100";;
    esac
}

# Function to deploy a symbol
deploy_symbol() {
    local symbol=$1
    local priority=$2
    local memory=$3
    local restart=$4
    
    echo -e "${YELLOW}Deploying $symbol...${NC}"
    
    # Create override file for this symbol
    override_dir="/etc/systemd/system/kdb-ticker@${symbol}.service.d"
    sudo mkdir -p "$override_dir"
    
    # Create override configuration
    sudo cat > "$override_dir/override.conf" << EOF
[Service]
# Symbol-specific configuration
Environment="SYMBOL=$symbol"
MemoryLimit=${memory}M
CPUWeight=$(get_cpu_weight $priority)
Restart=$restart

# Logging
SyslogIdentifier=kdb-ticker-$symbol
EOF
    
    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable "kdb-ticker@${symbol}.service"
    
    if sudo systemctl is-active --quiet "kdb-ticker@${symbol}.service"; then
        echo -e "${GREEN}✓ $symbol already running${NC}"
    else
        sudo systemctl start "kdb-ticker@${symbol}.service"
        echo -e "${GREEN}✓ $symbol started${NC}"
    fi
}

# Ensure KDB+ server is running
echo -e "${YELLOW}Checking KDB+ server...${NC}"
if ! sudo systemctl is-active --quiet kdb-server.service; then
    echo -e "${YELLOW}Starting KDB+ server...${NC}"
    sudo systemctl start kdb-server.service
    sleep 5
fi
echo -e "${GREEN}✓ KDB+ server is running${NC}"
echo ""

# Read config and deploy symbols
echo -e "${YELLOW}Reading symbol configuration...${NC}"
deployed=0
skipped=0

while IFS=',' read -r symbol priority memory restart || [ -n "$symbol" ]; do
    # Skip comments and empty lines
    if [[ "$symbol" =~ ^[[:space:]]*# ]] || [[ -z "$symbol" ]]; then
        continue
    fi
    
    # Trim whitespace
    symbol=$(echo "$symbol" | xargs)
    priority=$(echo "$priority" | xargs)
    memory=$(echo "$memory" | xargs)
    restart=$(echo "$restart" | xargs)
    
    # Deploy the symbol
    deploy_symbol "$symbol" "$priority" "$memory" "$restart"
    deployed=$((deployed + 1))
    
done < "$CONFIG_FILE"

echo ""
echo -e "${BLUE}Deployment Summary${NC}"
echo -e "${BLUE}==================${NC}"
echo -e "${GREEN}Deployed: $deployed symbols${NC}"

# Show status
echo ""
echo -e "${YELLOW}Current Status:${NC}"
sudo systemctl list-units 'kdb-ticker@*.service' --no-legend | while read -r line; do
    unit=$(echo "$line" | awk '{print $1}')
    status=$(echo "$line" | awk '{print $3}')
    symbol=$(echo "$unit" | sed 's/kdb-ticker@\(.*\)\.service/\1/')
    
    if [ "$status" = "active" ]; then
        echo -e "${GREEN}✓ $symbol - active${NC}"
    else
        echo -e "${RED}✗ $symbol - $status${NC}"
    fi
done

echo ""
echo -e "${BLUE}Management Commands:${NC}"
echo "  View logs:    journalctl -u kdb-ticker@ethusdt -f"
echo "  Check status: systemctl status 'kdb-ticker@*'"
echo "  Stop symbol:  systemctl stop kdb-ticker@ethusdt"
echo "  Stop all:     systemctl stop 'kdb-ticker@*'"
echo "" 