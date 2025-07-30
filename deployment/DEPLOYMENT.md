# KDB+ Ticker System - Production Deployment Guide

This guide provides detailed instructions for deploying the KDB+ Ticker System in production environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Deployment Options](#deployment-options)
3. [Systemd Deployment](#systemd-deployment)
4. [Docker Deployment](#docker-deployment)
5. [Configuration](#configuration)
6. [Monitoring](#monitoring)
7. [Maintenance](#maintenance)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

- Linux server (Ubuntu 20.04+ or CentOS 8+)
- KDB+ 4.0+ license
- 8GB+ RAM (minimum)
- 100GB+ disk space
- Root or sudo access
- Open port 5001 (configurable)

## Deployment Options

### Option 1: Systemd (Recommended for single-server deployments)

Best for:
- Single server deployments
- Direct hardware access needed
- Integration with existing monitoring

### Option 2: Docker (Recommended for containerized environments)

Best for:
- Kubernetes deployments
- Multi-server setups
- Development/testing environments

## Systemd Deployment

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y build-essential git netcat

# CentOS/RHEL
sudo yum install -y gcc git nc
```

### 2. Build the Project

```bash
# Clone repository
git clone <repository-url> /opt/kdb-ticker
cd /opt/kdb-ticker

# Build Rust client
make build
```

### 3. Install KDB+

```bash
# Copy your KDB+ binary to /usr/local/bin/q
sudo cp /path/to/q /usr/local/bin/
sudo chmod +x /usr/local/bin/q
```

### 4. Install Systemd Services

```bash
cd deployment/systemd
sudo ./install.sh
```

### 5. Configure Symbols

Edit `/opt/kdb-ticker/deployment/config/symbols.conf`:
```
ethusdt,high,512,always
btcusdt,high,512,always
bnbusdt,medium,256,always
```

### 6. Deploy Multiple Symbols

```bash
cd deployment/scripts
sudo ./deploy-multi-symbol.sh
```

### 7. Verify Deployment

```bash
# Check status
sudo systemctl status kdb-server
sudo systemctl status 'kdb-ticker@*'

# View logs
sudo journalctl -u kdb-server -f
sudo journalctl -u kdb-ticker@ethusdt -f
```

## Docker Deployment

### 1. Install Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. Build Images

```bash
cd deployment/docker
docker-compose build
```

### 3. Configure Environment

Create `.env` file:
```env
# KDB+ Configuration
KDB_DATA_PATH=/data/kdb
KDB_LOG_PATH=/logs/kdb
KDB_ARCHIVE_PATH=/archive/kdb

# Symbols to track
SYMBOLS=ethusdt,btcusdt,bnbusdt

# Resource limits
KDB_MEMORY_LIMIT=4G
CLIENT_MEMORY_LIMIT=512M
```

### 4. Start Services

```bash
# Start all services
docker-compose up -d

# Start specific symbols
docker-compose up -d kdb-server ticker-ethusdt ticker-btcusdt

# View logs
docker-compose logs -f
```

### 5. Scale Services

```bash
# Add more symbols
docker-compose up -d ticker-solusdt ticker-adausdt
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KDB_HOST` | KDB+ server hostname | localhost |
| `KDB_PORT` | KDB+ server port | 5001 |
| `SYMBOL` | Trading pair to track | ethusdt |
| `RUST_LOG` | Log level (debug/info/warn/error) | info |
| `KDB_DATA_PATH` | Data storage path | /data |
| `KDB_LOG_PATH` | Log files path | /logs |
| `KDB_ARCHIVE_PATH` | Archive path | /archive |

### KDB+ Configuration

Edit `src/q/tick_persist.q` for:
- Persistence intervals
- Archive schedule
- Memory limits
- Table schemas

### Resource Limits

Adjust in systemd service files or docker-compose.yml:
- CPU quota
- Memory limits
- File descriptor limits
- Process limits

## Monitoring

### 1. System Metrics

Monitor using the built-in KDB+ functions:
```q
// Connect to KDB+
q) h:hopen `:localhost:5001

// Check system status
q) h".monitor.status[]"

// View ingestion stats
q) h"ingestionStats[]"

// Check data quality
q) h"dataQuality[`ticker]"
```

### 2. Prometheus Integration

Export metrics for Prometheus:
```bash
# Install node exporter (included in docker-compose)
docker-compose up -d node-exporter

# Metrics available at http://localhost:9100/metrics
```

### 3. Log Monitoring

```bash
# Systemd logs
sudo journalctl -u kdb-server --since "1 hour ago"

# Docker logs
docker-compose logs --tail=100 -f

# Application logs
tail -f /opt/kdb-ticker/logs/ticker_*.log
```

## Maintenance

### Data Management

1. **Manual Backup**
   ```bash
   # Backup current data
   tar -czf backup_$(date +%Y%m%d).tar.gz /opt/kdb-ticker/data/
   ```

2. **Archive Old Data**
   ```q
   // Connect to KDB+
   q) h:hopen `:localhost:5001
   
   // Trigger manual archive
   q) h".persist.archive[]"
   ```

3. **Clean Up Logs**
   ```bash
   # Set up log rotation
   sudo cat > /etc/logrotate.d/kdb-ticker << EOF
   /opt/kdb-ticker/logs/*.log {
       daily
       rotate 7
       compress
       missingok
       notifempty
   }
   EOF
   ```

### Updates

1. **Update Code**
   ```bash
   cd /opt/kdb-ticker
   git pull
   make build
   ```

2. **Restart Services**
   ```bash
   # Systemd
   sudo systemctl restart kdb-server
   sudo systemctl restart 'kdb-ticker@*'
   
   # Docker
   docker-compose down
   docker-compose up -d
   ```

### Performance Tuning

1. **KDB+ Memory**
   ```bash
   # Edit service file
   sudo systemctl edit kdb-server
   
   # Add:
   [Service]
   Environment="QARGS=-w 8000"  # 8GB workspace
   ```

2. **Batch Sizes**
   Edit `src/rust/src/kdb/client.rs`:
   ```rust
   const BATCH_SIZE: usize = 100;  // Adjust based on throughput
   const BATCH_TIMEOUT: Duration = Duration::from_millis(500);
   ```

## Troubleshooting

### Common Issues

1. **KDB+ Connection Failed**
   ```bash
   # Check if KDB+ is running
   sudo systemctl status kdb-server
   nc -zv localhost 5001
   
   # Check firewall
   sudo ufw status
   sudo iptables -L
   ```

2. **High Memory Usage**
   ```bash
   # Check memory usage
   free -h
   ps aux | grep -E 'q|kdb-ticker'
   
   # Adjust limits
   sudo systemctl edit kdb-ticker@ethusdt
   ```

3. **WebSocket Disconnections**
   ```bash
   # Check network connectivity
   ping api.binance.com
   
   # Check logs for errors
   journalctl -u kdb-ticker@ethusdt | grep ERROR
   ```

4. **Data Not Persisting**
   ```bash
   # Check disk space
   df -h
   
   # Check permissions
   ls -la /opt/kdb-ticker/data/
   
   # Check KDB+ logs
   grep ERROR /opt/kdb-ticker/logs/ticker_*.log
   ```

### Debug Mode

Enable debug logging:
```bash
# Systemd
sudo systemctl edit kdb-ticker@ethusdt
# Add: Environment="RUST_LOG=debug"

# Docker
RUST_LOG=debug docker-compose up ticker-ethusdt
```

### Recovery Procedures

1. **Recover from Crash**
   ```bash
   # Check for core dumps
   sudo coredumpctl list
   
   # Restart services
   sudo systemctl restart kdb-server
   sudo systemctl restart 'kdb-ticker@*'
   ```

2. **Restore from Backup**
   ```bash
   # Stop services
   sudo systemctl stop 'kdb-ticker@*'
   sudo systemctl stop kdb-server
   
   # Restore data
   tar -xzf backup_20240115.tar.gz -C /
   
   # Start services
   sudo systemctl start kdb-server
   sudo systemctl start 'kdb-ticker@*'
   ```

## Security Considerations

1. **Network Security**
   - Use firewall rules to restrict KDB+ port access
   - Consider VPN for remote access
   - Use TLS for production (requires KDB+ SSL license)

2. **User Permissions**
   - Run services as non-root user
   - Restrict file permissions
   - Use systemd security features

3. **Data Protection**
   - Encrypt data at rest
   - Regular backups
   - Audit logging

## Support

For issues or questions:
1. Check logs first
2. Review this guide
3. Check GitHub issues
4. Contact support team 