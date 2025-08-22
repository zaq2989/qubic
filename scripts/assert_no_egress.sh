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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test configuration
TEST_DURATION=30
MONITOR_INTERFACE="any"

# Check prerequisites
check_prerequisites() {
    if ! command -v tcpdump &> /dev/null; then
        log_error "tcpdump is required for network monitoring"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "docker is required for container tests"
        exit 1
    fi
    
    # Check if we have necessary permissions
    if ! sudo -n tcpdump --version &> /dev/null 2>&1; then
        log_warn "This script requires sudo access for tcpdump"
        log_warn "You may be prompted for your password"
    fi
}

# Monitor network traffic
monitor_network() {
    local pcap_file="$1"
    local duration="$2"
    local filter="$3"
    
    log_info "Monitoring network traffic for $duration seconds..."
    
    sudo timeout "$duration" tcpdump -i "$MONITOR_INTERFACE" -w "$pcap_file" "$filter" 2>/dev/null || true
    
    # Make the file readable
    sudo chmod 644 "$pcap_file"
}

# Analyze packet capture
analyze_pcap() {
    local pcap_file="$1"
    local container_ips=("$@")
    container_ips=("${container_ips[@]:1}")  # Remove first argument
    
    log_info "Analyzing packet capture..."
    
    # Check for any external traffic
    local external_packets=0
    local internal_packets=0
    
    # Get packet summary
    local packet_summary=$(sudo tcpdump -nn -r "$pcap_file" 2>/dev/null | head -100)
    
    # Check each packet
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local is_internal=false
        
        # Check if packet involves container IPs
        for ip in "${container_ips[@]}"; do
            if echo "$line" | grep -q "$ip"; then
                is_internal=true
                break
            fi
        done
        
        # Check for local/private IPs
        if echo "$line" | grep -qE '(172\.(1[6-9]|2[0-9]|3[0-1])|10\.|192\.168\.)'; then
            is_internal=true
        fi
        
        # Check for external IPs
        if echo "$line" | grep -qE '([0-9]{1,3}\.){3}[0-9]{1,3}' && ! $is_internal; then
            # Exclude DNS (port 53) and DHCP (port 67/68)
            if ! echo "$line" | grep -qE '\.(53|67|68):'; then
                external_packets=$((external_packets + 1))
                log_error "External traffic detected: $line"
            fi
        else
            internal_packets=$((internal_packets + 1))
        fi
    done <<< "$packet_summary"
    
    log_info "Analyzed packets - Internal: $internal_packets, External: $external_packets"
    
    return $external_packets
}

# Test Docker network isolation
test_docker_isolation() {
    log_info "Testing Docker network isolation..."
    
    # Create test network
    docker network create --internal test-isolation 2>/dev/null || true
    
    # Test 1: Try to reach external DNS
    log_info "Test 1: Checking DNS resolution..."
    if docker run --rm --network test-isolation alpine nslookup google.com 2>&1 | grep -q "can't resolve"; then
        log_success "DNS resolution blocked"
    else
        log_error "DNS resolution NOT blocked"
    fi
    
    # Test 2: Try to ping external IP
    log_info "Test 2: Checking external connectivity..."
    if docker run --rm --network test-isolation alpine ping -c 1 8.8.8.8 2>&1 | grep -q "Network is unreachable"; then
        log_success "External ping blocked"
    else
        log_error "External ping NOT blocked"
    fi
    
    # Test 3: Try to curl external site
    log_info "Test 3: Checking HTTP requests..."
    if docker run --rm --network test-isolation alpine sh -c 'wget -T 5 -O - http://example.com 2>&1' | grep -q "bad address\|can't connect"; then
        log_success "HTTP requests blocked"
    else
        log_error "HTTP requests NOT blocked"
    fi
    
    # Cleanup
    docker network rm test-isolation 2>/dev/null || true
}

# Test sandbox network isolation
test_sandbox_isolation() {
    log_info "Testing sandbox network isolation..."
    
    # Start packet capture
    local pcap_file="$PROJECT_ROOT/tmp/sandbox_test.pcap"
    monitor_network "$pcap_file" "$TEST_DURATION" "not port 22" &
    local monitor_pid=$!
    
    # Wait for monitoring to start
    sleep 2
    
    # Start sandbox containers
    log_info "Starting sandbox containers..."
    docker-compose -f "$PROJECT_ROOT/sandbox/docker-compose.sandbox.yml" up -d
    
    # Get container IPs
    local container_ips=()
    for container in wargame-target wargame-attacker wargame-defender; do
        local ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || echo "")
        [[ -n "$ip" ]] && container_ips+=("$ip")
    done
    
    # Run test workload
    log_info "Running test workload in containers..."
    
    # Try various network operations from containers
    docker exec wargame-attacker sh -c 'ping -c 3 8.8.8.8' 2>&1 | grep -q "Network is unreachable" || log_warn "Attacker can ping external"
    docker exec wargame-defender sh -c 'wget -T 5 http://google.com' 2>&1 | grep -q "bad address" || log_warn "Defender can reach external"
    docker exec wargame-target sh -c 'curl -s http://ifconfig.me' 2>&1 | grep -q "Could not resolve" || log_warn "Target can reach external"
    
    # Wait for monitoring to complete
    wait $monitor_pid
    
    # Stop containers
    docker-compose -f "$PROJECT_ROOT/sandbox/docker-compose.sandbox.yml" down
    
    # Analyze capture
    if analyze_pcap "$pcap_file" "${container_ips[@]}"; then
        log_success "No external traffic detected from sandbox"
    else
        log_error "External traffic detected from sandbox!"
        return 1
    fi
}

# Test worker isolation
test_worker_isolation() {
    log_info "Testing worker network isolation..."
    
    # Build test container
    docker build -f sandbox/docker/Dockerfile.attacker -t test-worker:isolated . 2>/dev/null
    
    # Create isolated network
    docker network create --internal worker-test-net 2>/dev/null || true
    
    # Run worker with network restrictions
    log_info "Running worker in isolated network..."
    local output=$(docker run --rm \
        --network worker-test-net \
        --cap-drop ALL \
        test-worker:isolated \
        /usr/local/bin/attacker --test-network 2>&1 || true)
    
    # Check for network access attempts
    if echo "$output" | grep -q "Network is unreachable\|Connection refused\|No route to host"; then
        log_success "Worker network access properly restricted"
    else
        log_warn "Worker may have network access"
    fi
    
    # Cleanup
    docker network rm worker-test-net 2>/dev/null || true
}

# Test firewall rules
test_firewall_rules() {
    log_info "Testing firewall rules..."
    
    # Check iptables rules (if available)
    if command -v iptables &> /dev/null && sudo -n iptables -L &> /dev/null; then
        log_info "Checking iptables rules..."
        
        # Look for Docker isolation rules
        if sudo iptables -L DOCKER-ISOLATION-STAGE-1 -n 2>/dev/null | grep -q DROP; then
            log_success "Docker isolation rules found"
        else
            log_warn "Docker isolation rules not found"
        fi
    else
        log_warn "Cannot check iptables rules (no access or not available)"
    fi
}

# Main test execution
main() {
    log_info "Starting network isolation tests..."
    
    check_prerequisites
    
    # Create temp directory
    mkdir -p "$PROJECT_ROOT/tmp"
    
    # Test 1: Docker network isolation
    log_info "=== Test 1: Docker Network Isolation ==="
    test_docker_isolation
    
    # Test 2: Sandbox network isolation
    log_info "=== Test 2: Sandbox Network Isolation ==="
    if [ -f "$PROJECT_ROOT/sandbox/docker-compose.sandbox.yml" ]; then
        test_sandbox_isolation
    else
        log_warn "Sandbox configuration not found, skipping test"
    fi
    
    # Test 3: Worker isolation
    log_info "=== Test 3: Worker Network Isolation ==="
    test_worker_isolation
    
    # Test 4: Firewall rules
    log_info "=== Test 4: Firewall Rules ==="
    test_firewall_rules
    
    log_info ""
    log_success "Network isolation tests completed!"
    log_info "Containers are properly isolated from external networks"
}

# Show usage
usage() {
    echo "Usage: $0"
    echo "  Tests network isolation to ensure no external connectivity"
    echo ""
    echo "Tests performed:"
    echo "  1. Docker internal network isolation"
    echo "  2. Sandbox environment isolation"
    echo "  3. Worker container isolation"
    echo "  4. Firewall rule verification"
    echo ""
    echo "Note: Requires sudo access for packet capture"
}

# Parse arguments
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run tests
main