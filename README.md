# KDB+ Real-Time Market Data Platform

A high-performance, scalable platform for ingesting and analyzing real-time cryptocurrency market data using KDB+ and Rust.

## Overview

This platform demonstrates the power of KDB+ for real-time financial data analytics by:

- Ingesting live ticker data from Binance WebSocket API
- Storing data in KDB+ for ultra-fast time-series analysis
- Providing practical analytics use cases for trading operations
- Achieving sub-millisecond latency for data processing

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Binance API    │────▶│  Rust Client     │────▶│   KDB+ Server   │
│  (WebSocket)    │     │  (Async/Tokio)   │     │   (Port 5001)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │                          │
                                ▼                          ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │  Message Queue   │     │   Q Analytics   │
                        │  (Channel/MPSC)  │     │   (Scripts)     │
                        └──────────────────┘     └─────────────────┘
```

## Features

- **Real-time Data Ingestion**: WebSocket client with automatic reconnection
- **Batch Processing**: Efficient batch inserts to KDB+ for optimal performance
- **Analytics Suite**: VWAP, order book analysis, volatility metrics, and more
- **Performance Monitoring**: Built-in latency tracking and system metrics
- **Production Ready**: Error handling, logging, and monitoring

## Prerequisites

- Rust 1.75+ (install from https://rustup.rs/)
- KDB+ 4.0+ (download from https://kx.com/developers/download/)
- Make (build automation)

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd kdb-tickers
   ```

2. **Start KDB+ server**
   ```bash
   make kdb-start
   ```

3. **Build and run the WebSocket client**
   ```bash
   make build
   make run
   ```

## Configuration

Configure the system using environment variables:

```bash
export SYMBOL=ethusdt      # Trading pair (default: ethusdt)
export KDB_HOST=localhost  # KDB+ host (default: localhost)
export KDB_PORT=5001       # KDB+ port (default: 5001)
export RUST_LOG=info       # Log level (default: info)
```

## Project Structure

```text
kdb-tickers/
├── src/
│   ├── rust/              # Rust WebSocket client
│   │   ├── binance/       # Binance WebSocket handling
│   │   ├── kdb/           # KDB+ client implementation
│   │   └── models/        # Data models
│   └── q/                 # KDB+ scripts
│       ├── init.q         # Database initialization
│       ├── tick.q         # Real-time data handler
│       └── analytics/     # Analytics scripts
│           ├── vwap.q     # VWAP calculations
│           ├── orderbook.q # Order book analysis
│           ├── volatility.q # Volatility metrics
│           └── performance.q # Performance monitoring
├── tests/                 # Test suite
├── docs/                  # Documentation
└── Makefile              # Build automation
```

## Analytics Use Cases

### 1. VWAP (Volume Weighted Average Price)

Calculate VWAP for different time windows:

```q
// Load VWAP analytics
\l src/q/analytics/vwap.q

// Calculate VWAP for last hour
calcVWAP["ETHUSDT"; .z.P-01:00:00; .z.P]

// Get rolling 5-minute VWAP
rollingVWAP["ETHUSDT"; 00:05:00]

// Calculate VWAP deviation
vwapDeviation["ETHUSDT"; 00:05:00]
```

### 2. Order Book Analysis

Analyze bid/ask spreads and market depth:

```q
// Load order book analytics
\l src/q/analytics/orderbook.q

// Analyze spreads
spreadAnalysis["ETHUSDT"; 01:00:00]

// Check order book imbalance
bookImbalance["ETHUSDT"]

// Calculate liquidity score
liquidityScore["ETHUSDT"; 00:30:00]
```

### 3. Volatility Analysis

Calculate various volatility metrics:

```q
// Load volatility analytics
\l src/q/analytics/volatility.q

// Historical volatility
historicalVolatility["ETHUSDT"; 01:00:00; 365*24*60*60]

// Volatility term structure
volTermStructure["ETHUSDT"]

// Risk metrics (VaR, ES)
riskMetrics["ETHUSDT"; 01:00:00; 0.95]
```

### 4. Performance Monitoring

Monitor system performance and data quality:

```q
// Load performance analytics
\l src/q/analytics/performance.q

// Get ingestion statistics
ingestionStats[]

// Check data quality
dataQuality["ETHUSDT"; 01:00:00]

// System monitoring
systemMonitor[]
```

## Testing

The project includes a robust test suite covering unit tests, integration tests, and performance benchmarks.

### Test Structure

```
tests/
├── test_init.q         # Unit tests for init.q module
├── test_tick.q         # Unit tests for tick.q module  
├── test_analytics.q    # Comprehensive analytics tests
└── test_integration.q  # End-to-end integration tests
```

### Running Tests

#### Quick Test Run
```bash
# Run all tests
make test

# Run only Q/KDB+ tests
make test-q

# Run only Rust tests  
make test-rust

# Run specific test suites
make test-analytics
make test-integration
```

#### Comprehensive Test Suite
```bash
# Run full test suite with detailed reporting
./scripts/run_tests.sh
```

### Test Categories

#### 1. Unit Tests
- **init.q tests**: Verify table schemas, utility functions, and initialization
- **tick.q tests**: Test real-time data handling, updates, and bar generation

#### 2. Analytics Tests
Comprehensive testing of all analytics functions:
- VWAP calculations (simple, rolling, bucketed, intraday)
- Order book analytics (spread, imbalance, micro-price, liquidity)
- Volatility metrics (historical, Parkinson, Garman-Klass, realized)
- Performance monitoring and data quality checks

#### 3. Integration Tests
End-to-end testing scenarios:
- Complete data flow from ingestion to analytics
- High-frequency data handling (1000+ updates/second)
- Error handling and data validation
- Concurrent multi-symbol updates
- Memory efficiency testing

#### 4. Performance Benchmarks
Each test suite includes performance assertions:
- VWAP calculation: <100ms for 10k records
- Spread analysis: <200ms for 10k records
- Volatility calculation: <500ms for 10k records
- Data insertion: <1ms per batch

### Test Utilities

The test framework provides assertion helpers:
```q
.test.assert[name;condition;message]      // Basic assertion
.test.assertEq[name;actual;expected;msg]  // Equality assertion
.test.assertClose[name;actual;expected;tolerance;msg]  // Numeric tolerance
```

### Test Reports

After running tests, a detailed report is generated:
```
test_report_YYYYMMDD_HHMMSS.txt
```

Example output:
```
KDB+ Analytics Test Suite
========================

=== Testing VWAP Analytics ===
✓ VWAP-Simple-NotNull: Simple VWAP should return a value
✓ VWAP-Simple-Positive: Simple VWAP should be positive
✓ VWAP-Rolling-Count: Rolling VWAP count should match ticker count
...

========================
Test Summary:
  Passed: 45
  Failed: 0
  Total:  45
```

### Continuous Integration

The test suite is designed to be CI/CD friendly:
- Exit codes indicate success (0) or failure (1)
- Quiet mode suppresses verbose output
- Performance metrics can be tracked over time
- Test reports provide detailed failure information

### Adding New Tests

To add new tests:

1. Create a new test file in `tests/` directory
2. Follow the naming convention: `test_<module>.q`
3. Include test utilities and assertions
4. Add the test to the Makefile and run_tests.sh

Example test structure:
```q
/ Test suite for new module
\l ../src/q/new_module.q

.test.assert:{[name;condition;msg] /* ... */ }

testNewFeature:{[]
  -1"Testing new feature...";
  / Test implementation
  .test.assert["test-name";condition;"Test description"];
 }

runTests:{[]
  -1"New Module Test Suite";
  testNewFeature[];
  -1"Tests completed.";
 }

runTests[];
```

## Development

### Building from Source

```bash
# Build Rust client
make build

# Run tests
make test

# Format code
make fmt

# Run linter
make lint
```

### Running Tests

```bash
# Run all tests
make test

# Run Rust tests only
make test-rust

# Run q tests only
make test-q
```

## Performance

The platform is designed for high performance:

- **Latency**: Sub-millisecond from data receipt to KDB+ storage
- **Throughput**: Handles 1000+ messages/second per symbol
- **Batch Processing**: Configurable batch sizes for optimal performance
- **Memory Efficient**: Circular buffer prevents memory bloat

## Monitoring

Built-in monitoring capabilities:

- Real-time performance metrics
- Data quality checks
- System resource monitoring
- Latency tracking

Access monitoring through KDB+:
```q
// Real-time dashboard data
dashboardData[]
```

## Troubleshooting

### Common Issues

1. **KDB+ Connection Failed**
   - Ensure KDB+ is running: `make kdb-start`
   - Check port availability: `lsof -i :5001`
   - Verify firewall settings

2. **WebSocket Connection Issues**
   - Check internet connectivity
   - Verify Binance API is accessible
   - Check for rate limiting

3. **High Memory Usage**
   - Adjust batch size in `src/rust/src/kdb/client.rs`
   - Implement data archiving strategy
   - Monitor with `systemMonitor[]`

## Advanced Usage

### Adding New Trading Pairs

```bash
# Run multiple instances for different pairs
SYMBOL=btcusdt make client &
SYMBOL=ethusdt make client &
```

### Custom Analytics

Create new analytics in `src/q/analytics/`:

```q
// myanalytic.q
h:hopen `::5001

myCustomAnalytic:{[sym;params]
  data:h"select from ticker where sym=`$sym";
  // Your analysis here
}
```

### Production Deployment

The system is production-ready with several deployment options:

### Features

- **Systemd Services**: Automatic startup and process management
- **Docker Support**: Containerized deployment with docker-compose
- **Multi-Symbol**: Configurable multi-symbol support
- **Data Persistence**: Automatic data saving and archiving
- **Monitoring**: Built-in health checks and metrics
- **High Availability**: Automatic restart and recovery

### Quick Deploy

#### Systemd (Recommended)
```bash
cd deployment/systemd
sudo ./install.sh
cd ../scripts
sudo ./deploy-multi-symbol.sh
```

#### Docker
```bash
cd deployment/docker
docker-compose up -d
```

See [deployment/DEPLOYMENT.md](deployment/DEPLOYMENT.md) for detailed instructions.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- KX Systems for KDB+
- Binance for market data API
- Rust async ecosystem (Tokio, Tungstenite)

## Resources

- [KDB+ Documentation](https://code.kx.com/)
- [Binance API Documentation](https://binance-docs.github.io/apidocs/)
- [Tokio Documentation](https://tokio.rs/)
- [Rust Async Book](https://rust-lang.github.io/async-book/)