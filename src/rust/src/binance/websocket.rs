use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use futures_util::{SinkExt, StreamExt};
use serde_json;
use std::time::Duration;
use tokio::sync::mpsc;
use tokio_tungstenite::{connect_async, tungstenite::Message};
use tracing::{debug, error, info, warn};

use crate::models::ticker::{BinanceTicker, KdbTicker};

const BINANCE_WS_URL: &str = "wss://stream.binance.com:9443/ws";

pub struct BinanceWebSocketClient {
    tx: mpsc::Sender<KdbTicker>,
}

impl BinanceWebSocketClient {
    pub fn new(tx: mpsc::Sender<KdbTicker>) -> Self {
        Self { tx }
    }

    pub async fn connect_and_stream(&mut self) -> Result<()> {
        let symbol = std::env::var("SYMBOL").unwrap_or_else(|_| "ethusdt".to_string());
        let url = format!("{}/{}@ticker", BINANCE_WS_URL, symbol);
        
        info!("Connecting to Binance WebSocket: {}", url);
        
        loop {
            match self.run_websocket_loop(&url).await {
                Ok(_) => {
                    info!("WebSocket connection closed normally");
                }
                Err(e) => {
                    error!("WebSocket error: {}", e);
                    info!("Reconnecting in 5 seconds...");
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    }

    async fn run_websocket_loop(&mut self, url: &str) -> Result<()> {
        let (ws_stream, _) = connect_async(url).await
            .context("Failed to connect to WebSocket")?;
        
        info!("Connected to Binance WebSocket");
        
        let (mut write, mut read) = ws_stream.split();
        
        // Send ping periodically to keep connection alive
        let ping_task = {
            let mut write_clone = write.clone();
            tokio::spawn(async move {
                let mut interval = tokio::time::interval(Duration::from_secs(30));
                loop {
                    interval.tick().await;
                    if write_clone.send(Message::Ping(vec![].into())).await.is_err() {
                        break;
                    }
                }
            })
        };
        
        // Read messages
        while let Some(msg) = read.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    if let Err(e) = self.handle_message(&text).await {
                        error!("Error processing message: {}", e);
                    }
                }
                Ok(Message::Ping(_)) => {
                    debug!("Received ping");
                }
                Ok(Message::Pong(_)) => {
                    debug!("Received pong");
                }
                Ok(Message::Close(_)) => {
                    info!("Received close message");
                    break;
                }
                Err(e) => {
                    error!("WebSocket error: {}", e);
                    break;
                }
                _ => {}
            }
        }
        
        ping_task.abort();
        Ok(())
    }
    
    async fn handle_message(&mut self, text: &str) -> Result<()> {
        debug!("Received message: {}", text);
        
        let binance_ticker: BinanceTicker = serde_json::from_str(text)
            .context("Failed to parse Binance ticker")?;
        
        let kdb_ticker = KdbTicker::from(binance_ticker);
        
        if let Err(e) = self.tx.send(kdb_ticker).await {
            error!("Failed to send ticker to KDB client: {}", e);
            return Err(e.into());
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_websocket_client_creation() {
        let (tx, _rx) = mpsc::channel(100);
        let _client = BinanceWebSocketClient::new(tx);
        // Just test that it compiles and constructs
    }
}
