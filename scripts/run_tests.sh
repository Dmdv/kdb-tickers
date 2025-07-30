#!/bin/bash

# KDB+ Ticker System Test Runner
# Runs all tests and generates a summary report

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0
SKIPPED=0

# Print header
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}KDB+ Ticker System Test Suite${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to run a test
run_test() {
    local test_name=$1
    local test_cmd=$2
    
    echo -e "${YELLOW}Running: $test_name${NC}"
    
    if eval "$test_cmd" > /tmp/test_output_$$.log 2>&1; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        PASSED=$((PASSED + 1))
        
        # Show performance metrics if available
        if grep -q "Performance Summary:" /tmp/test_output_$$.log; then
            echo -e "${BLUE}  Performance metrics:${NC}"
            grep -A 5 "Performance Summary:" /tmp/test_output_$$.log | tail -n +2 | sed 's/^/    /'
        fi
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        FAILED=$((FAILED + 1))
        echo -e "${RED}  Error output:${NC}"
        tail -n 10 /tmp/test_output_$$.log | sed 's/^/    /'
    fi
    
    rm -f /tmp/test_output_$$.log
    echo ""
}

# Check if KDB+ is available
if ! command -v q &> /dev/null; then
    echo -e "${RED}Error: q (KDB+) is not installed or not in PATH${NC}"
    exit 1
fi

# Start KDB+ if not running
if ! nc -z localhost 5001 2>/dev/null; then
    echo -e "${YELLOW}Starting KDB+ server...${NC}"
    nohup q src/q/tick.q -p 5001 > /tmp/kdb_test.log 2>&1 &
    KDB_PID=$!
    sleep 2
    
    if ! nc -z localhost 5001; then
        echo -e "${RED}Failed to start KDB+ server${NC}"
        exit 1
    fi
    echo -e "${GREEN}KDB+ server started (PID: $KDB_PID)${NC}"
    echo ""
fi

# Run Q/KDB+ tests
echo -e "${BLUE}=== Q/KDB+ Tests ===${NC}"
echo ""

run_test "Init Module Tests" "q tests/test_init.q -q"
run_test "Tick Module Tests" "q tests/test_tick.q -q"
run_test "Analytics Tests" "q tests/test_analytics.q -q"
run_test "Integration Tests" "q tests/test_integration.q -q"

# Run Rust tests if cargo is available
if command -v cargo &> /dev/null; then
    echo -e "${BLUE}=== Rust Tests ===${NC}"
    echo ""
    
    run_test "Rust Unit Tests" "cd src/rust && cargo test --quiet"
    
    # Check for tarpaulin for coverage
    if cargo install --list | grep -q "cargo-tarpaulin"; then
        run_test "Rust Coverage" "cd src/rust && cargo tarpaulin --print-summary"
    else
        echo -e "${YELLOW}Skipping coverage (cargo-tarpaulin not installed)${NC}"
        SKIPPED=$((SKIPPED + 1))
    fi
else
    echo -e "${YELLOW}Skipping Rust tests (cargo not found)${NC}"
    SKIPPED=$((SKIPPED + 2))
fi

echo ""

# Cleanup
if [ ! -z "$KDB_PID" ]; then
    echo -e "${YELLOW}Stopping test KDB+ server...${NC}"
    kill $KDB_PID 2>/dev/null || true
fi

# Print summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Passed:  $PASSED${NC}"
echo -e "${RED}Failed:  $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo -e "${BLUE}Total:   $((PASSED + FAILED + SKIPPED))${NC}"
echo ""

# Generate test report
REPORT_FILE="test_report_$(date +%Y%m%d_%H%M%S).txt"
cat > $REPORT_FILE << EOF
KDB+ Ticker System Test Report
Generated: $(date)

Test Results:
- Passed:  $PASSED
- Failed:  $FAILED  
- Skipped: $SKIPPED
- Total:   $((PASSED + FAILED + SKIPPED))

Success Rate: $(echo "scale=2; $PASSED * 100 / ($PASSED + $FAILED)" | bc)%
EOF

echo -e "${BLUE}Test report saved to: $REPORT_FILE${NC}"

# Exit with appropriate code
if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi 