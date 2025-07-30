# KDB+ Real-Time Market Data Platform Makefile

# Variables
RUST_DIR = src/rust
Q_DIR = src/q
DOCS_DIR = docs
TEST_DIR = tests
SCRIPTS_DIR = scripts

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

# Default target
.PHONY: all
all: build

# Help target
.PHONY: help
help:
	@echo "$(GREEN)KDB+ Market Data Platform$(NC)"
	@echo "Available targets:"
	@echo "  $(YELLOW)build$(NC)       - Build Rust WebSocket client"
	@echo "  $(YELLOW)test$(NC)        - Run all tests"
	@echo "  $(YELLOW)run$(NC)         - Start the complete system"
	@echo "  $(YELLOW)kdb-start$(NC)   - Start KDB+ server"
	@echo "  $(YELLOW)kdb-stop$(NC)    - Stop KDB+ server"
	@echo "  $(YELLOW)client$(NC)      - Run WebSocket client"
	@echo "  $(YELLOW)analytics$(NC)   - Run analytics examples"
	@echo "  $(YELLOW)clean$(NC)       - Clean build artifacts"
	@echo "  $(YELLOW)docs$(NC)        - Generate documentation"
	@echo "  $(YELLOW)bench$(NC)       - Run performance benchmarks"
	@echo "  $(YELLOW)lint$(NC)        - Run linting tools"
	@echo "  $(YELLOW)fmt$(NC)         - Format code"
	@echo "  $(YELLOW)setup$(NC)       - Initial setup"

# Setup target
.PHONY: setup
setup:
	@echo "$(GREEN)Setting up project...$(NC)"
	cd $(RUST_DIR) && cargo init --name kdb-ticker-client
	@echo "$(GREEN)Setup complete!$(NC)"

# Build targets
.PHONY: build
build: build-rust

.PHONY: build-rust
build-rust:
	@echo "$(GREEN)Building Rust WebSocket client...$(NC)"
	cd $(RUST_DIR) && cargo build --release
	@echo "$(GREEN)Build complete!$(NC)"

##@ Testing

.PHONY: test
test: test-rust test-q ## Run all tests

.PHONY: test-rust
test-rust: ## Run Rust tests
	@echo "$(GREEN)Running Rust tests...$(NC)"
	cd $(RUST_DIR) && cargo test

.PHONY: test-q
test-q: kdb-start ## Run Q/KDB+ tests
	@echo "$(GREEN)Running Q/KDB+ tests...$(NC)"
	@echo "$(YELLOW)Testing init.q...$(NC)"
	q tests/test_init.q -q
	@echo ""
	@echo "$(YELLOW)Testing tick.q...$(NC)"
	q tests/test_tick.q -q
	@echo ""
	@echo "$(YELLOW)Testing analytics...$(NC)"
	q tests/test_analytics.q -q
	@echo ""
	@echo "$(YELLOW)Running integration tests...$(NC)"
	q tests/test_integration.q -q
	@echo "$(GREEN)All Q tests completed!$(NC)"

.PHONY: test-analytics
test-analytics: kdb-start ## Run only analytics tests
	@echo "$(GREEN)Running analytics tests...$(NC)"
	q tests/test_analytics.q test.q -q

.PHONY: test-integration
test-integration: kdb-start ## Run only integration tests
	@echo "$(GREEN)Running integration tests...$(NC)"
	q tests/test_integration.q -q

.PHONY: test-coverage
test-coverage: ## Run tests with coverage (Rust only)
	@echo "$(GREEN)Running Rust tests with coverage...$(NC)"
	cd $(RUST_DIR) && cargo tarpaulin --out Html

##@ Client Operations

# Run targets
.PHONY: run
run: kdb-start
	@echo "$(GREEN)Starting complete system...$(NC)"
	@sleep 2
	@make client

.PHONY: kdb-start
kdb-start:
	@echo "$(GREEN)Starting KDB+ server...$(NC)"
	@if ! pgrep -f "q.*5001" > /dev/null; then \
		nohup q $(Q_DIR)/tick.q -p 5001 > logs/kdb.log 2>&1 & \
		echo "$$!" > .kdb.pid; \
		sleep 2; \
		echo "$(GREEN)KDB+ started on port 5001$(NC)"; \
	else \
		echo "$(YELLOW)KDB+ already running$(NC)"; \
	fi

.PHONY: kdb-stop
kdb-stop:
	@echo "$(GREEN)Stopping KDB+ server...$(NC)"
	@if [ -f .kdb.pid ]; then \
		kill `cat .kdb.pid` 2>/dev/null || true; \
		rm -f .kdb.pid; \
		echo "$(GREEN)KDB+ stopped$(NC)"; \
	else \
		pkill -f "q.*5001" 2>/dev/null || true; \
		echo "$(GREEN)KDB+ processes terminated$(NC)"; \
	fi

.PHONY: client
client:
	@echo "$(GREEN)Running WebSocket client...$(NC)"
	cd $(RUST_DIR) && cargo run --release

# Analytics targets
.PHONY: analytics
analytics:
	@echo "$(GREEN)Running analytics examples...$(NC)"
	@for script in $(Q_DIR)/analytics/*.q; do \
		if [ -f "$$script" ]; then \
			echo "$(YELLOW)Running $$(basename $$script)...$(NC)"; \
			q $$script -q; \
		fi \
	done

# Maintenance targets
.PHONY: clean
clean:
	@echo "$(GREEN)Cleaning build artifacts...$(NC)"
	cd $(RUST_DIR) && cargo clean
	rm -f logs/*.log
	rm -f .kdb.pid
	@echo "$(GREEN)Clean complete!$(NC)"

.PHONY: lint
lint: lint-rust

.PHONY: lint-rust
lint-rust:
	@echo "$(GREEN)Running Rust linter...$(NC)"
	cd $(RUST_DIR) && cargo clippy -- -D warnings

.PHONY: fmt
fmt: fmt-rust

.PHONY: fmt-rust
fmt-rust:
	@echo "$(GREEN)Formatting Rust code...$(NC)"
	cd $(RUST_DIR) && cargo fmt

# Documentation targets
.PHONY: docs
docs:
	@echo "$(GREEN)Generating documentation...$(NC)"
	cd $(RUST_DIR) && cargo doc --no-deps --open
	@echo "$(GREEN)Documentation generated!$(NC)"

# Benchmark targets
.PHONY: bench
bench: bench-rust bench-kdb

.PHONY: bench-rust
bench-rust:
	@echo "$(GREEN)Running Rust benchmarks...$(NC)"
	cd $(RUST_DIR) && cargo bench

.PHONY: bench-kdb
bench-kdb:
	@echo "$(GREEN)Running KDB+ benchmarks...$(NC)"
	@if [ -f "$(Q_DIR)/benchmarks.q" ]; then \
		q $(Q_DIR)/benchmarks.q -q; \
	else \
		echo "$(YELLOW)No benchmarks found$(NC)"; \
	fi

# Monitoring targets
.PHONY: monitor
monitor:
	@echo "$(GREEN)Monitoring system performance...$(NC)"
	@if [ -f "$(SCRIPTS_DIR)/monitor.sh" ]; then \
		bash $(SCRIPTS_DIR)/monitor.sh; \
	else \
		echo "$(YELLOW)Monitor script not found$(NC)"; \
	fi

# Directory creation
.PHONY: dirs
dirs:
	@mkdir -p logs
	@mkdir -p $(RUST_DIR)
	@mkdir -p $(Q_DIR)/analytics
	@mkdir -p $(DOCS_DIR)
	@mkdir -p $(TEST_DIR)
	@mkdir -p $(SCRIPTS_DIR) 