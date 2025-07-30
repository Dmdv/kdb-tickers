use anyhow::Result;
use std::env;
use tokio::sync::mpsc;
use tracing::{error, info};
use tracing_subscriber::EnvFilter;

use kdb_ticker_client::{BinanceWebSocketClient, KdbClient};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    info!("Starting KDB+ Ticker Client");

    // Configuration from environment variables
    let symbol = env::var("SYMBOL").unwrap_or_else(|_| "ethusdt".to_string());
    let kdb_host = env::var("KDB_HOST").unwrap_or_else(|_| "localhost".to_string());
    let kdb_port: u16 = env::var("KDB_PORT")
        .unwrap_or_else(|_| "5001".to_string())
        .parse()
        .unwrap_or(5001);

    info!("Configuration:");
    info!("  Symbol: {}", symbol);
    info!("  KDB+ Host: {}", kdb_host);
    info!("  KDB+ Port: {}", kdb_port);

    // Create channel for communication between WebSocket and KDB client
    let (tx, rx) = mpsc::channel(1000);

    // Create KDB client
    let mut kdb_client = KdbClient::new(kdb_host, kdb_port);
    
    // Connect to KDB+
    match kdb_client.connect().await {
        Ok(_) => info!("Connected to KDB+"),
        Err(e) => {
            error!("Failed to connect to KDB+: {:?}", e);
            error!("Make sure KDB+ is running on {}:{}", kdb_client.host, kdb_client.port);
            return Err(e);
        }
    }

    // Create WebSocket client
    let mut ws_client = BinanceWebSocketClient::new(symbol, tx);

    // Spawn KDB batch processor
    let kdb_handle = tokio::spawn(async move {
        if let Err(e) = kdb_client.start_batch_processor(rx).await {
            error!("KDB batch processor error: {:?}", e);
        }
    });

    // Spawn WebSocket client
    let ws_handle = tokio::spawn(async move {
        if let Err(e) = ws_client.connect_and_stream().await {
            error!("WebSocket client error: {:?}", e);
        }
    });

    // Wait for tasks to complete (they shouldn't unless there's an error)
    tokio::select! {
        _ = kdb_handle => {
            error!("KDB processor terminated");
        }
        _ = ws_handle => {
            error!("WebSocket client terminated");
        }
        _ = tokio::signal::ctrl_c() => {
            info!("Received shutdown signal");
        }
    }

    info!("Shutting down KDB+ Ticker Client");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_main_exists() {
        // Simple test to ensure main compiles
        assert!(true);
    }
}
