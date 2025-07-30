# Multi-stage Dockerfile for KDB+ Ticker System

# Stage 1: Build Rust client
FROM rust:1.75-slim as rust-builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy Rust source files
COPY src/rust/Cargo.toml src/rust/Cargo.lock ./
COPY src/rust/src ./src

# Build release binary
RUN cargo build --release

# Stage 2: KDB+ base image
FROM ubuntu:22.04 as kdb-base

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    rlwrap \
    netcat \
    && rm -rf /var/lib/apt/lists/*

# Download and install KDB+ (you need to provide your own license)
# Note: In production, you should copy your licensed KDB+ binary
ARG KDB_VERSION=4.0
RUN mkdir -p /opt/kdb && \
    cd /opt/kdb && \
    wget https://github.com/KxSystems/kdb/releases/download/${KDB_VERSION}/l64.zip && \
    unzip l64.zip && \
    rm l64.zip && \
    chmod +x q/l64/q

# Add q to PATH
ENV PATH="/opt/kdb/q/l64:${PATH}"
ENV QHOME="/opt/kdb/q"

# Stage 3: Final image
FROM kdb-base

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -u 1000 -s /bin/bash kdb

# Create directory structure
RUN mkdir -p /app/{src/q,logs,data,archive} && \
    chown -R kdb:kdb /app

# Copy Rust binary from builder
COPY --from=rust-builder /app/target/release/kdb-ticker-client /app/kdb-ticker-client

# Copy Q scripts
COPY src/q /app/src/q

# Copy supervisor config
COPY deployment/docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy startup script
COPY deployment/docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Environment variables
ENV RUST_LOG=info
ENV KDB_HOST=localhost
ENV KDB_PORT=5001
ENV SYMBOL=ethusdt
ENV KDB_DATA_PATH=/app/data
ENV KDB_LOG_PATH=/app/logs
ENV KDB_ARCHIVE_PATH=/app/archive

# Expose KDB+ port
EXPOSE 5001

# Volume for data persistence
VOLUME ["/app/data", "/app/logs", "/app/archive"]

# Switch to app user
USER kdb
WORKDIR /app

# Use supervisor to manage multiple processes
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"] 