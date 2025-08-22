#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

# Test categories
run_unit_tests() {
    log_section "Running Unit Tests"
    
    # Python unit tests
    log_info "Running Python unit tests..."
    python3 -m pytest "$SCRIPT_DIR/unit/" -v || return 1
    
    # Go unit tests
    log_info "Running Go unit tests..."
    cd "$PROJECT_ROOT/relay" && go test ./... || return 1
    cd "$PROJECT_ROOT/storage" && go test ./... || return 1
    
    # Rust unit tests
    log_info "Running Rust unit tests..."
    cd "$PROJECT_ROOT/workers/attacker" && cargo test || return 1
    cd "$PROJECT_ROOT/workers/defender" && cargo test || return 1
    
    # JavaScript unit tests
    log_info "Running JavaScript unit tests..."
    cd "$PROJECT_ROOT/dashboard" && npm test || return 1
    
    cd "$PROJECT_ROOT"
    return 0
}

run_integration_tests() {
    log_section "Running Integration Tests"
    
    log_info "Running integration tests..."
    python3 -m pytest "$SCRIPT_DIR/integration/" -v || return 1
    
    return 0
}

run_e2e_tests() {
    log_section "Running End-to-End Tests"
    
    log_info "Running E2E tests..."
    python3 -m pytest "$SCRIPT_DIR/e2e/" -v || return 1
    
    return 0
}

run_determinism_tests() {
    log_section "Running Determinism Tests"
    
    "$PROJECT_ROOT/scripts/assert_determinism.sh" || return 1
    
    return 0
}

run_security_tests() {
    log_section "Running Security Tests"
    
    # Network isolation
    if [[ "${SKIP_NETWORK_TESTS:-}" != "true" ]]; then
        "$PROJECT_ROOT/scripts/assert_no_egress.sh" || return 1
    else
        log_info "Skipping network tests (SKIP_NETWORK_TESTS=true)"
    fi
    
    return 0
}

# Generate test report
generate_report() {
    local report_file="$PROJECT_ROOT/test-report.txt"
    
    cat > "$report_file" <<EOF
Qubic Wargame Grid Test Report
==============================
Date: $(date)
Branch: $(git branch --show-current 2>/dev/null || echo "unknown")
Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

Test Results:
EOF
    
    for result in "$@"; do
        echo "$result" >> "$report_file"
    done
    
    log_info "Test report saved to: $report_file"
}

# Main test runner
main() {
    local failed=0
    local results=()
    
    log_info "Starting test suite..."
    
    # Check prerequisites
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required for tests"
        exit 1
    fi
    
    if ! python3 -m pip show pytest &> /dev/null; then
        log_info "Installing pytest..."
        python3 -m pip install pytest
    fi
    
    # Run test categories based on arguments
    if [[ $# -eq 0 ]] || [[ "$1" == "all" ]]; then
        # Run all tests
        if run_unit_tests; then
            results+=("✓ Unit Tests: PASSED")
        else
            results+=("✗ Unit Tests: FAILED")
            failed=$((failed + 1))
        fi
        
        if run_integration_tests; then
            results+=("✓ Integration Tests: PASSED")
        else
            results+=("✗ Integration Tests: FAILED")
            failed=$((failed + 1))
        fi
        
        if run_e2e_tests; then
            results+=("✓ E2E Tests: PASSED")
        else
            results+=("✗ E2E Tests: FAILED")
            failed=$((failed + 1))
        fi
        
        if run_determinism_tests; then
            results+=("✓ Determinism Tests: PASSED")
        else
            results+=("✗ Determinism Tests: FAILED")
            failed=$((failed + 1))
        fi
        
        if run_security_tests; then
            results+=("✓ Security Tests: PASSED")
        else
            results+=("✗ Security Tests: FAILED")
            failed=$((failed + 1))
        fi
    else
        # Run specific test category
        case "$1" in
            unit)
                if run_unit_tests; then
                    results+=("✓ Unit Tests: PASSED")
                else
                    results+=("✗ Unit Tests: FAILED")
                    failed=1
                fi
                ;;
            integration)
                if run_integration_tests; then
                    results+=("✓ Integration Tests: PASSED")
                else
                    results+=("✗ Integration Tests: FAILED")
                    failed=1
                fi
                ;;
            e2e)
                if run_e2e_tests; then
                    results+=("✓ E2E Tests: PASSED")
                else
                    results+=("✗ E2E Tests: FAILED")
                    failed=1
                fi
                ;;
            determinism)
                if run_determinism_tests; then
                    results+=("✓ Determinism Tests: PASSED")
                else
                    results+=("✗ Determinism Tests: FAILED")
                    failed=1
                fi
                ;;
            security)
                if run_security_tests; then
                    results+=("✓ Security Tests: PASSED")
                else
                    results+=("✗ Security Tests: FAILED")
                    failed=1
                fi
                ;;
            *)
                log_error "Unknown test category: $1"
                echo "Usage: $0 [all|unit|integration|e2e|determinism|security]"
                exit 1
                ;;
        esac
    fi
    
    # Generate report
    generate_report "${results[@]}"
    
    # Summary
    echo ""
    log_section "Test Summary"
    for result in "${results[@]}"; do
        echo "$result"
    done
    
    if [[ $failed -eq 0 ]]; then
        echo ""
        log_info "All tests passed! ✨"
        exit 0
    else
        echo ""
        log_error "$failed test suite(s) failed"
        exit 1
    fi
}

# Run main if script is executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi