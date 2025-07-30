use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Binance 24hr ticker statistics event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinanceTicker {
    #[serde(rename = "e")]
    pub event_type: String,
    
    #[serde(rename = "E")]
    pub event_time: u64,
    
    #[serde(rename = "s")]
    pub symbol: String,
    
    #[serde(rename = "p")]
    pub price_change: String,
    
    #[serde(rename = "P")]
    pub price_change_percent: String,
    
    #[serde(rename = "w")]
    pub weighted_avg_price: String,
    
    #[serde(rename = "x")]
    pub prev_close_price: String,
    
    #[serde(rename = "c")]
    pub last_price: String,
    
    #[serde(rename = "Q")]
    pub last_quantity: String,
    
    #[serde(rename = "b")]
    pub bid_price: String,
    
    #[serde(rename = "B")]
    pub bid_quantity: String,
    
    #[serde(rename = "a")]
    pub ask_price: String,
    
    #[serde(rename = "A")]
    pub ask_quantity: String,
    
    #[serde(rename = "o")]
    pub open_price: String,
    
    #[serde(rename = "h")]
    pub high_price: String,
    
    #[serde(rename = "l")]
    pub low_price: String,
    
    #[serde(rename = "v")]
    pub base_volume: String,
    
    #[serde(rename = "q")]
    pub quote_volume: String,
    
    #[serde(rename = "O")]
    pub stats_open_time: u64,
    
    #[serde(rename = "C")]
    pub stats_close_time: u64,
    
    #[serde(rename = "F")]
    pub first_trade_id: i64,
    
    #[serde(rename = "L")]
    pub last_trade_id: i64,
    
    #[serde(rename = "n")]
    pub count: u64,
}

/// Normalized ticker data for KDB+ storage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KdbTicker {
    pub time: DateTime<Utc>,
    pub sym: String,
    pub bid: f64,
    pub ask: f64,
    pub bid_size: f64,
    pub ask_size: f64,
    pub last: f64,
    pub volume: f64,
}

impl From<BinanceTicker> for KdbTicker {
    fn from(binance: BinanceTicker) -> Self {
        // Convert milliseconds to DateTime
        let time = DateTime::from_timestamp_millis(binance.event_time as i64)
            .unwrap_or_else(|| Utc::now());
        
        Self {
            time,
            sym: binance.symbol,
            bid: binance.bid_price.parse().unwrap_or(0.0),
            ask: binance.ask_price.parse().unwrap_or(0.0),
            bid_size: binance.bid_quantity.parse().unwrap_or(0.0),
            ask_size: binance.ask_quantity.parse().unwrap_or(0.0),
            last: binance.last_price.parse().unwrap_or(0.0),
            volume: binance.base_volume.parse().unwrap_or(0.0),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_binance_ticker_deserialization() {
        let json = r#"{
            "e": "24hrTicker",
            "E": 1672531200000,
            "s": "ETHUSDT",
            "p": "50.00",
            "P": "2.50",
            "w": "2050.00",
            "x": "2000.00",
            "c": "2050.00",
            "Q": "10",
            "b": "2049.00",
            "B": "100",
            "a": "2051.00",
            "A": "150",
            "o": "2000.00",
            "h": "2100.00",
            "l": "1950.00",
            "v": "50000",
            "q": "100000000",
            "O": 1672444800000,
            "C": 1672531200000,
            "F": 100,
            "L": 200,
            "n": 101
        }"#;

        let ticker: BinanceTicker = serde_json::from_str(json).unwrap();
        assert_eq!(ticker.symbol, "ETHUSDT");
        assert_eq!(ticker.last_price, "2050.00");
    }

    #[test]
    fn test_kdb_ticker_conversion() {
        let binance = BinanceTicker {
            event_type: "24hrTicker".to_string(),
            event_time: 1672531200000,
            symbol: "ETHUSDT".to_string(),
            price_change: "50.00".to_string(),
            price_change_percent: "2.50".to_string(),
            weighted_avg_price: "2050.00".to_string(),
            prev_close_price: "2000.00".to_string(),
            last_price: "2050.00".to_string(),
            last_quantity: "10".to_string(),
            bid_price: "2049.00".to_string(),
            bid_quantity: "100".to_string(),
            ask_price: "2051.00".to_string(),
            ask_quantity: "150".to_string(),
            open_price: "2000.00".to_string(),
            high_price: "2100.00".to_string(),
            low_price: "1950.00".to_string(),
            base_volume: "50000".to_string(),
            quote_volume: "100000000".to_string(),
            stats_open_time: 1672444800000,
            stats_close_time: 1672531200000,
            first_trade_id: 100,
            last_trade_id: 200,
            count: 101,
        };

        let kdb: KdbTicker = binance.into();
        assert_eq!(kdb.sym, "ETHUSDT");
        assert_eq!(kdb.bid, 2049.0);
        assert_eq!(kdb.ask, 2051.0);
        assert_eq!(kdb.last, 2050.0);
    }
}
