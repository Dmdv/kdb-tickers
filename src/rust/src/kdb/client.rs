use anyhow::{Context, Result};
use bytes::{BufMut, BytesMut};
use std::collections::VecDeque;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::{mpsc, Mutex};
use tokio::time::{interval, Duration};
use tracing::{debug, error, info, warn};

use crate::models::KdbTicker;

const KDB_BATCH_SIZE: usize = 100;
const KDB_FLUSH_INTERVAL: Duration = Duration::from_secs(1);

pub struct KdbClient {
    pub host: String,
    pub port: u16,
    stream: Option<Arc<Mutex<TcpStream>>>,
    buffer: Arc<Mutex<VecDeque<KdbTicker>>>,
}

impl KdbClient {
    pub fn new(host: String, port: u16) -> Self {
        Self {
            host,
            port,
            stream: None,
            buffer: Arc::new(Mutex::new(VecDeque::new())),
        }
    }

    pub async fn connect(&mut self) -> Result<()> {
        let addr = format!("{}:{}", self.host, self.port);
        info!("Connecting to KDB+ at {}", addr);
        
        let mut stream = TcpStream::connect(&addr)
            .await
            .context("Failed to connect to KDB+")?;
        
        // KDB+ handshake
        self.perform_handshake(&mut stream).await?;
        
        self.stream = Some(Arc::new(Mutex::new(stream)));
        info!("Connected to KDB+ successfully");
        
        Ok(())
    }

    async fn perform_handshake(&self, stream: &mut TcpStream) -> Result<()> {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        
        // Send null-terminated username (empty for no auth)
        stream.write_all(b"\x00").await?;
        
        // Read capability byte
        let mut cap = [0u8; 1];
        stream.read_exact(&mut cap).await?;
        
        debug!("KDB+ capability byte: {:02x}", cap[0]);
        
        Ok(())
    }

    pub async fn start_batch_processor(&self, mut rx: mpsc::Receiver<KdbTicker>) -> Result<()> {
        let buffer = self.buffer.clone();
        
        // Spawn a task to collect tickers into the buffer
        tokio::spawn(async move {
            while let Some(ticker) = rx.recv().await {
                let mut buf = buffer.lock().await;
                buf.push_back(ticker);
                
                // If buffer is getting large, log a warning
                if buf.len() > KDB_BATCH_SIZE * 10 {
                    warn!("KDB buffer growing large: {} items", buf.len());
                }
            }
        });
        
        // Periodically flush the buffer to KDB+
        let mut flush_interval = interval(KDB_FLUSH_INTERVAL);
        
        loop {
            flush_interval.tick().await;
            
            let mut buf = self.buffer.lock().await;
            if !buf.is_empty() {
                let batch: Vec<KdbTicker> = buf.drain(..).collect();
                drop(buf); // Release lock before IO
                
                if let Err(e) = self.send_batch(batch.clone()).await {
                    error!("Failed to send batch to KDB+: {:?}", e);
                    // Re-add failed batch to buffer
                    let mut buf = self.buffer.lock().await;
                    for ticker in batch {
                        buf.push_front(ticker);
                    }
                }
            }
        }
    }

    async fn send_batch(&self, batch: Vec<KdbTicker>) -> Result<()> {
        if batch.is_empty() {
            return Ok(());
        }
        
        info!("Sending batch of {} tickers to KDB+", batch.len());
        
        let stream_arc = self.stream.as_ref().context("Not connected to KDB+")?;
        let mut stream = stream_arc.lock().await;
        
        // Build q command to insert data
        let q_cmd = self.build_insert_command(&batch);
        
        // Encode and send
        let encoded = self.encode_q_message(&q_cmd)?;
        stream.write_all(&encoded).await?;
        
        // Read response
        let response = self.read_response(&mut *stream).await?;
        debug!("KDB+ response: {:?}", response);
        
        Ok(())
    }

    fn build_insert_command(&self, batch: &[KdbTicker]) -> String {
        let mut times = Vec::new();
        let mut syms = Vec::new();
        let mut bids = Vec::new();
        let mut asks = Vec::new();
        let mut bid_sizes = Vec::new();
        let mut ask_sizes = Vec::new();
        let mut lasts = Vec::new();
        let mut volumes = Vec::new();
        
        for ticker in batch {
            // Convert DateTime to KDB+ timestamp format (nanoseconds since 2000.01.01)
            let kdb_epoch = chrono::NaiveDate::from_ymd_opt(2000, 1, 1)
                .unwrap()
                .and_hms_opt(0, 0, 0)
                .unwrap()
                .and_utc();
            let nanos_since_kdb_epoch = (ticker.time - kdb_epoch).num_nanoseconds().unwrap_or(0);
            times.push(format!("0D{}", nanos_since_kdb_epoch));
            syms.push(format!("`{}", ticker.sym));
            bids.push(format!("{}", ticker.bid));
            asks.push(format!("{}", ticker.ask));
            bid_sizes.push(format!("{}", ticker.bid_size));
            ask_sizes.push(format!("{}", ticker.ask_size));
            lasts.push(format!("{}", ticker.last));
            volumes.push(format!("{}", ticker.volume));
        }
        
        format!(
            "`ticker insert ([] time:{}; sym:{}; bid:{}; ask:{}; bidSize:{}; askSize:{}; last:{}; volume:{})",
            times.join(" "),
            syms.join(" "),
            bids.join(" "),
            asks.join(" "),
            bid_sizes.join(" "),
            ask_sizes.join(" "),
            lasts.join(" "),
            volumes.join(" ")
        )
    }

    fn encode_q_message(&self, msg: &str) -> Result<Vec<u8>> {
        let mut buf = BytesMut::new();
        
        // Message header
        buf.put_u8(0x01); // little endian
        buf.put_u8(0x00); // async message
        buf.put_u8(0x00); // compression
        buf.put_u8(0x00); // reserved
        
        // Message length (header + data)
        let msg_bytes = msg.as_bytes();
        let total_len = 8 + msg_bytes.len() + 1; // header + message + null terminator
        buf.put_u32_le(total_len as u32);
        
        // Message type (10 = char vector)
        buf.put_u8(0x0a);
        buf.put_u8(0x00); // attributes
        
        // Message data
        buf.put(msg_bytes);
        buf.put_u8(0x00); // null terminator
        
        Ok(buf.to_vec())
    }

    async fn read_response(&self, stream: &mut TcpStream) -> Result<Vec<u8>> {
        // Read header
        let mut header = [0u8; 8];
        stream.read_exact(&mut header).await?;
        
        let msg_len = u32::from_le_bytes([header[4], header[5], header[6], header[7]]) as usize;
        
        // Read message body
        let mut body = vec![0u8; msg_len - 8];
        stream.read_exact(&mut body).await?;
        
        Ok(body)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_kdb_client_creation() {
        let client = KdbClient::new("localhost".to_string(), 5001);
        assert_eq!(client.host, "localhost");
        assert_eq!(client.port, 5001);
    }
}
