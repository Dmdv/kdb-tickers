use anyhow::{Context, Result};
use futures_util::{SinkExt, StreamExt};
use tokio::sync::mpsc;
use tokio_tungstenite::{connect_async, tungstenite::Message};
use tracing::{debug, error, info, warn};

use crate::models::{BinanceTicker, KdbTicker};

const BINANCE_WS_URL: &str = "wss://stream.binance.com:9443/ws";

pub struct BinanceWebSocketClient {
    symbol: String,
    tx: mpsc::Sender<KdbTicker>,
}

impl BinanceWebSocketClient {
    pub fn new(symbol: String, tx: mpsc::Sender<KdbTicker>) -> Self {
        Self { symbol, tx }
    }

    pub async fn connect_and_stream(&mut self) -> Result<()> {
        let stream_name = format!("{}@ticker", self.symbol.to_lowercase());
        let url = format!("{}/{}", BINANCE_WS_URL, stream_name);
        
        info!("Connecting to Binance WebSocket: {}", url);
        
        loop {
            match self.run_websocket_loop(&url).await {
                Ok(_) => {
                    warn!("WebSocket connection closed normally");
                }
                Err(e) => {
                    error!("WebSocket error: {:?}", e);
                }
            }
            
            // Reconnect with exponential backoff
            warn!("Reconnecting in 5 seconds...");
            tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        }
    }

    async fn run_websocket_loop(&mut self, url: &str) -> Result<()> {
        let (ws_stream, _) = connect_async(url).await.context("Failed to connect to WebSocket")?;
        
        info!("WebSocket connected successfully");
        
        let (mut write, mut read) = ws_stream.split();
        
        // Send ping every 30 seconds to keep connection alive
        let mut ping_interval = tokio::time::interval(tokio::time::Duration::from_secs(30));
        
        loop {
            tokio::select! {
                // Handle incoming messages
                msg = read.next() => {
                    match msg {
                        Some(Ok(Message::Text(text))) => {
                            self.handle_message(&text).await?;
                        }
                        Some(Ok(Message::Ping(data))) => {
                            debug!("Received ping, sending pong");
                            write.send(Message::Pong(data)).await?;
                        }
                        Some(Ok(Message::Close(_))) => {
                            info!("Received close frame");
                            break;
                        }
                        Some(Err(e)) => {
                            error!("WebSocket error: {:?}", e);
                            return Err(e.into());
                        }
                        None => {
                            warn!("WebSocket stream ended");
                            break;
                        }
                        _ => {}
                    }
                }
                
                // Send periodic pings
                _ = ping_interval.tick() => {
                    debug!("Sending ping");
                    write.send(Message::Ping(vec![].into())).await?;
                }
            }
        }
        
        Ok(())
    }

    async fn handle_message(&mut self, text: &str) -> Result<()> {
        match serde_json::from_str::<BinanceTicker>(text) {
            Ok(binance_ticker) => {
                debug!("Received ticker: {:?}", binance_ticker);
                
                // Convert to KDB format
                let kdb_ticker: KdbTicker = binance_ticker.into();
                
                // Send to KDB client via channel
                if let Err(e) = self.tx.send(kdb_ticker).await {
                    error!("Failed to send ticker to channel: {:?}", e);
                }
            }
            Err(e) => {
                warn!("Failed to parse ticker message: {:?}, raw: {}", e, text);
            }
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::mpsc;

    #[tokio::test]
    async fn test_websocket_client_creation() {
        let (tx, _rx) = mpsc::channel(100);
        let client = BinanceWebSocketClient::new("ETHUSDT".to_string(), tx);
        assert_eq!(client.symbol, "ETHUSDT");
    }
}
