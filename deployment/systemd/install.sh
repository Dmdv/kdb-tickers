#!/bin/bash

# KDB+ Ticker System - Systemd Installation Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}Installing KDB+ Ticker System Services${NC}"

# Create kdb user if it doesn't exist
if ! id -u kdb >/dev/null 2>&1; then
    echo -e "${YELLOW}Creating kdb user...${NC}"
    useradd -r -s /bin/false -d /opt/kdb-ticker -m kdb
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p /opt/kdb-ticker/{logs,data,src,target}
chown -R kdb:kdb /opt/kdb-ticker

# Copy files
echo -e "${YELLOW}Copying application files...${NC}"
cp -r ../../../src /opt/kdb-ticker/
cp -r ../../../target /opt/kdb-ticker/ 2>/dev/null || echo "Note: Build the Rust client first"

# Copy systemd service files
echo -e "${YELLOW}Installing systemd services...${NC}"
cp kdb-server.service /etc/systemd/system/
cp kdb-ticker.service /etc/systemd/system/
cp kdb-ticker@.service /etc/systemd/system/
cp kdb-ticker.target /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable services
echo -e "${YELLOW}Enabling services...${NC}"
systemctl enable kdb-server.service
systemctl enable kdb-ticker.target

echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "To start the system:"
echo "  systemctl start kdb-server"
echo "  systemctl start kdb-ticker@ethusdt"
echo "  systemctl start kdb-ticker@btcusdt"
echo ""
echo "To enable multiple symbols:"
echo "  systemctl enable kdb-ticker@ethusdt"
echo "  systemctl enable kdb-ticker@btcusdt"
echo "  systemctl enable kdb-ticker@bnbusdt"
echo ""
echo "To check status:"
echo "  systemctl status kdb-server"
echo "  systemctl status kdb-ticker@ethusdt"
echo "  journalctl -u kdb-server -f"
echo "" 