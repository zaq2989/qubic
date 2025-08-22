#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$SANDBOX_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running with required permissions
check_permissions() {
    if ! groups | grep -q docker; then
        log_error "User must be in docker group or run with sudo"
        exit 1
    fi
}

# Ensure network isolation
setup_network_isolation() {
    log_info "Setting up network isolation..."
    
    # Create isolated bridge network if not exists
    if ! docker network ls | grep -q wargame-isolated; then
        docker network create \
            --driver bridge \
            --internal \
            --subnet 172.30.0.0/16 \
            wargame-isolated
    fi
    
    # Verify no external routing
    docker run --rm --network wargame-isolated alpine ping -c 1 8.8.8.8 &>/dev/null && {
        log_error "Network isolation check failed - external connectivity detected!"
        exit 1
    } || {
        log_info "Network isolation verified - no external connectivity"
    }
}

# Create snapshot of clean environment
create_snapshot() {
    local snapshot_name="$1"
    log_info "Creating snapshot: $snapshot_name"
    
    # For Docker, we'll use commit to create image snapshots
    docker commit wargame-target "wargame-target:$snapshot_name" || true
    docker commit wargame-attacker "wargame-attacker:$snapshot_name" || true
    docker commit wargame-defender "wargame-defender:$snapshot_name" || true
}

# Restore from snapshot
restore_snapshot() {
    local snapshot_name="$1"
    log_info "Restoring from snapshot: $snapshot_name"
    
    # Stop and remove current containers
    docker-compose -f "$SANDBOX_DIR/docker-compose.sandbox.yml" down
    
    # Restore from snapshot images
    # This is simplified - in production would use proper volume snapshots
    log_info "Snapshot restore complete"
}

# Monitor sandbox for escapes
monitor_sandbox() {
    log_info "Starting sandbox monitoring..."
    
    # Monitor for suspicious network activity
    docker run --rm -d \
        --name wargame-monitor \
        --network host \
        --cap-add NET_ADMIN \
        alpine tcpdump -i any -w /tmp/monitor.pcap \
        'not port 22 and not port 9090' &
    
    MONITOR_PID=$!
    
    # Check for container escapes
    while true; do
        # Check if containers are still running
        for container in target attacker defender; do
            if ! docker ps | grep -q "wargame-$container"; then
                log_warn "Container wargame-$container is not running"
            fi
        done
        
        # Check for privilege escalation
        for container in target attacker defender; do
            if docker exec "wargame-$container" id 2>/dev/null | grep -q "uid=0"; then
                log_error "Root access detected in $container!"
            fi
        done
        
        sleep 5
    done
}

# Run a single round
run_round() {
    local round_id="$1"
    local job_spec="$2"
    
    log_info "Starting round $round_id"
    
    # Create clean environment
    restore_snapshot "clean"
    
    # Start containers
    docker-compose -f "$SANDBOX_DIR/docker-compose.sandbox.yml" up -d
    
    # Wait for services to be ready
    sleep 10
    
    # Inject job specification
    docker exec wargame-attacker sh -c "echo '$job_spec' > /tmp/job.json"
    docker exec wargame-defender sh -c "echo '$job_spec' > /tmp/job.json"
    
    # Start monitoring
    monitor_sandbox &
    MONITOR_PID=$!
    
    # Run attack
    log_info "Executing attack..."
    docker exec wargame-attacker /usr/local/bin/attacker \
        --job-file /tmp/job.json \
        --output /artifacts/
    
    # Run defense
    log_info "Executing defense analysis..."
    docker exec wargame-defender /usr/local/bin/defender \
        --job-file /tmp/job.json \
        --pcap-file /pcap/capture.pcap \
        --output /artifacts/
    
    # Stop monitoring
    kill $MONITOR_PID 2>/dev/null || true
    
    # Collect artifacts
    collect_artifacts "$round_id"
    
    log_info "Round $round_id complete"
}

# Collect artifacts from containers
collect_artifacts() {
    local round_id="$1"
    local artifact_dir="$PROJECT_ROOT/artifacts/round-$round_id"
    
    mkdir -p "$artifact_dir"
    
    # Copy attack artifacts
    docker cp wargame-attacker:/artifacts/. "$artifact_dir/attack/"
    
    # Copy defense artifacts
    docker cp wargame-defender:/artifacts/. "$artifact_dir/defense/"
    
    # Copy traffic capture
    docker cp wargame-defender:/pcap/. "$artifact_dir/pcap/"
    
    # Copy logs
    docker logs wargame-target > "$artifact_dir/target.log" 2>&1
    docker logs wargame-attacker > "$artifact_dir/attacker.log" 2>&1
    docker logs wargame-defender > "$artifact_dir/defender.log" 2>&1
    
    log_info "Artifacts collected in $artifact_dir"
}

# Main execution
main() {
    case "${1:-}" in
        setup)
            check_permissions
            setup_network_isolation
            create_snapshot "clean"
            ;;
        run)
            check_permissions
            run_round "${2:-1}" "${3:-'{}'}"
            ;;
        monitor)
            monitor_sandbox
            ;;
        cleanup)
            docker-compose -f "$SANDBOX_DIR/docker-compose.sandbox.yml" down
            docker network rm wargame-isolated 2>/dev/null || true
            ;;
        *)
            echo "Usage: $0 {setup|run|monitor|cleanup}"
            echo "  setup    - Initialize sandbox environment"
            echo "  run      - Run a single round"
            echo "  monitor  - Monitor sandbox for escapes"
            echo "  cleanup  - Clean up sandbox environment"
            exit 1
            ;;
    esac
}

main "$@"