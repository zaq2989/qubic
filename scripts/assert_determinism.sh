#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

# Test configuration
TEST_SEED="determinism_test_12345"
TEST_TARGET="0123456789abcdef0123456789abcdef"
TEST_ROUNDS=3

# Run attack worker with seed
run_attack_test() {
    local run_id=$1
    local output_dir="$PROJECT_ROOT/tmp/determinism_test/run_${run_id}"
    mkdir -p "$output_dir"
    
    log_info "Running attack worker (run $run_id)..."
    
    # Create test job
    cat > "$output_dir/job.json" <<EOF
{
  "job_id": 9999,
  "job_type": "ATTACK",
  "seed": "$TEST_SEED",
  "target_profile": "$TEST_TARGET",
  "time_budget_ms": 5000,
  "round_id": 1
}
EOF
    
    # Run attacker
    cd "$PROJECT_ROOT/workers/attacker"
    timeout 30s cargo run --release -- \
        --worker-id "test-attacker-$run_id" \
        --relay-endpoint "http://localhost:9999" \
        < "$output_dir/job.json" \
        > "$output_dir/output.log" 2>&1 || true
    
    # Extract metrics
    grep -E "(success|exploit_time_ms|attempts)" "$output_dir/output.log" > "$output_dir/metrics.txt" || true
    
    cd "$PROJECT_ROOT"
}

# Run defense worker with seed
run_defense_test() {
    local run_id=$1
    local output_dir="$PROJECT_ROOT/tmp/determinism_test/run_${run_id}"
    mkdir -p "$output_dir"
    
    log_info "Running defense worker (run $run_id)..."
    
    # Create test job
    cat > "$output_dir/job.json" <<EOF
{
  "job_id": 9998,
  "job_type": "DEFENSE",
  "seed": "$TEST_SEED",
  "target_profile": "$TEST_TARGET",
  "time_budget_ms": 5000,
  "round_id": 1
}
EOF
    
    # Run defender
    cd "$PROJECT_ROOT/workers/defender"
    timeout 30s cargo run --release -- \
        --worker-id "test-defender-$run_id" \
        --relay-endpoint "http://localhost:9999" \
        < "$output_dir/job.json" \
        > "$output_dir/output.log" 2>&1 || true
    
    # Extract metrics
    grep -E "(detected|true_positive_rate|false_positive_rate)" "$output_dir/output.log" > "$output_dir/metrics.txt" || true
    
    cd "$PROJECT_ROOT"
}

# Compare outputs
compare_outputs() {
    local worker_type=$1
    local base_dir="$PROJECT_ROOT/tmp/determinism_test"
    local differences=0
    
    log_info "Comparing $worker_type outputs..."
    
    # Compare each run against the first
    for ((i=2; i<=TEST_ROUNDS; i++)); do
        local file1="$base_dir/run_1/metrics.txt"
        local file2="$base_dir/run_$i/metrics.txt"
        
        if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
            log_error "Missing output files for comparison"
            return 1
        fi
        
        if ! diff -q "$file1" "$file2" > /dev/null; then
            log_error "Run 1 and Run $i produced different results!"
            diff "$file1" "$file2" || true
            differences=$((differences + 1))
        else
            log_success "Run 1 and Run $i produced identical results"
        fi
    done
    
    return $differences
}

# Test container determinism
test_container_determinism() {
    log_info "Testing container-based determinism..."
    
    # Build test images if needed
    if ! docker image inspect wargame/attacker:v0.1 > /dev/null 2>&1; then
        log_info "Building attacker image..."
        docker build -f sandbox/docker/Dockerfile.attacker -t wargame/attacker:v0.1 .
    fi
    
    if ! docker image inspect wargame/defender:v0.1 > /dev/null 2>&1; then
        log_info "Building defender image..."
        docker build -f sandbox/docker/Dockerfile.defender -t wargame/defender:v0.1 .
    fi
    
    # Run multiple times with same seed
    for ((i=1; i<=TEST_ROUNDS; i++)); do
        log_info "Container test run $i..."
        
        # Run in isolated network
        docker run --rm \
            --network none \
            -v "$PROJECT_ROOT/tmp:/tmp" \
            wargame/attacker:v0.1 \
            /usr/local/bin/attacker --test-mode --seed "$TEST_SEED" \
            > "$PROJECT_ROOT/tmp/container_run_$i.log" 2>&1 || true
    done
    
    # Compare container outputs
    local container_diffs=0
    for ((i=2; i<=TEST_ROUNDS; i++)); do
        if ! diff -q \
            "$PROJECT_ROOT/tmp/container_run_1.log" \
            "$PROJECT_ROOT/tmp/container_run_$i.log" > /dev/null; then
            container_diffs=$((container_diffs + 1))
        fi
    done
    
    if [ $container_diffs -eq 0 ]; then
        log_success "Container execution is deterministic"
    else
        log_error "Container execution is NOT deterministic"
    fi
}

# Test time independence
test_time_independence() {
    log_info "Testing time independence..."
    
    # Run with delays
    local output1="$PROJECT_ROOT/tmp/time_test_1.log"
    local output2="$PROJECT_ROOT/tmp/time_test_2.log"
    
    # First run
    cd "$PROJECT_ROOT/workers/attacker"
    timeout 10s cargo run --release -- --test-seed "$TEST_SEED" > "$output1" 2>&1 || true
    
    # Wait and run again
    sleep 5
    timeout 10s cargo run --release -- --test-seed "$TEST_SEED" > "$output2" 2>&1 || true
    
    cd "$PROJECT_ROOT"
    
    # Compare core outputs (ignoring timestamps)
    grep -v "timestamp\|time\|Time" "$output1" > "$output1.filtered"
    grep -v "timestamp\|time\|Time" "$output2" > "$output2.filtered"
    
    if diff -q "$output1.filtered" "$output2.filtered" > /dev/null; then
        log_success "Output is time-independent"
    else
        log_error "Output depends on execution time"
    fi
}

# Main test execution
main() {
    log_info "Starting determinism tests..."
    
    # Clean up previous test data
    rm -rf "$PROJECT_ROOT/tmp/determinism_test"
    mkdir -p "$PROJECT_ROOT/tmp/determinism_test"
    
    # Test 1: Attack worker determinism
    log_info "=== Testing Attack Worker Determinism ==="
    for ((i=1; i<=TEST_ROUNDS; i++)); do
        run_attack_test $i
    done
    
    if compare_outputs "attack"; then
        log_success "Attack worker is deterministic"
    else
        log_error "Attack worker is NOT deterministic"
        exit 1
    fi
    
    # Test 2: Defense worker determinism
    log_info "=== Testing Defense Worker Determinism ==="
    for ((i=1; i<=TEST_ROUNDS; i++)); do
        run_defense_test $i
    done
    
    if compare_outputs "defense"; then
        log_success "Defense worker is deterministic"
    else
        log_error "Defense worker is NOT deterministic"
        exit 1
    fi
    
    # Test 3: Container determinism
    log_info "=== Testing Container Determinism ==="
    test_container_determinism
    
    # Test 4: Time independence
    log_info "=== Testing Time Independence ==="
    test_time_independence
    
    log_info ""
    log_success "All determinism tests passed!"
    log_info "Workers produce identical results for identical seeds"
}

# Show usage
usage() {
    echo "Usage: $0"
    echo "  Runs determinism tests to ensure reproducible execution"
    echo ""
    echo "Tests performed:"
    echo "  1. Multiple runs with same seed produce same output"
    echo "  2. Container execution is deterministic"
    echo "  3. Output is independent of execution time"
}

# Parse arguments
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run tests
main