#!/bin/bash
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
ROUND_ID=${1:-1}
NUM_JOBS=${2:-10}
SEED_BASE=${3:-"deadbeef"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Generate job specification
generate_job_spec() {
    local job_id=$1
    local job_type=$2
    local round_id=$3
    local seed="${SEED_BASE}$(printf "%04x" $job_id)"
    
    cat <<EOF
{
  "round_id": $round_id,
  "job_type": "$job_type",
  "seed": "$seed",
  "target_profile": "$(echo -n "target-$job_id" | sha256sum | cut -d' ' -f1)",
  "time_budget_ms": 5000
}
EOF
}

# Submit job to blockchain (mock)
submit_job() {
    local job_spec="$1"
    local job_file="$PROJECT_ROOT/tmp/job_${RANDOM}.json"
    
    echo "$job_spec" > "$job_file"
    
    # In real implementation, would call blockchain API
    # For PoC, we'll use curl to relay API
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$job_spec" \
        "http://localhost:8080/api/jobs" \
        || log_warn "Failed to submit job (relay might not be running)"
    
    rm -f "$job_file"
}

# Check services
check_services() {
    log_info "Checking required services..."
    
    # Check MinIO
    if ! curl -s http://localhost:9000/minio/health/live > /dev/null; then
        log_warn "MinIO is not running. Starting it..."
        docker start minio || docker run -d \
            --name minio \
            -p 9000:9000 \
            -p 9001:9001 \
            -e MINIO_ROOT_USER=minioadmin \
            -e MINIO_ROOT_PASSWORD=minioadmin \
            -v minio-data:/data \
            minio/minio server /data --console-address ":9001"
        sleep 5
    fi
    
    # Check relay (just warn if not running)
    if ! curl -s http://localhost:8080/api/health > /dev/null; then
        log_warn "Relay service is not running. Jobs won't be processed."
        log_warn "Start it with: cd relay && ./bin/relay"
    fi
}

# Run sandbox environment
run_sandbox_round() {
    log_info "Starting sandbox environment for round $ROUND_ID..."
    
    # Prepare job specifications
    local jobs_file="$PROJECT_ROOT/tmp/round_${ROUND_ID}_jobs.json"
    echo "[" > "$jobs_file"
    
    for ((i=1; i<=NUM_JOBS; i++)); do
        local job_type=$([[ $((i % 2)) -eq 0 ]] && echo "DEFENSE" || echo "ATTACK")
        local job_spec=$(generate_job_spec $i "$job_type" $ROUND_ID)
        
        echo "$job_spec" >> "$jobs_file"
        [[ $i -lt $NUM_JOBS ]] && echo "," >> "$jobs_file"
    done
    
    echo "]" >> "$jobs_file"
    
    # Run sandbox
    "$PROJECT_ROOT/sandbox/scripts/run_sandbox.sh" run "$ROUND_ID" "$jobs_file"
    
    rm -f "$jobs_file"
}

# Monitor round progress
monitor_round() {
    log_info "Monitoring round $ROUND_ID progress..."
    
    local completed=0
    local total=$NUM_JOBS
    
    while [ $completed -lt $total ]; do
        # Query round status (mock for PoC)
        if curl -s "http://localhost:8080/api/rounds/$ROUND_ID/summary" > /dev/null; then
            local summary=$(curl -s "http://localhost:8080/api/rounds/$ROUND_ID/summary")
            completed=$(echo "$summary" | jq -r '.completed_jobs // 0')
            
            echo -ne "\rProgress: $completed/$total jobs completed"
        fi
        
        sleep 2
    done
    
    echo ""
    log_info "Round $ROUND_ID completed!"
}

# Generate round report
generate_report() {
    log_info "Generating round report..."
    
    local report_file="$PROJECT_ROOT/artifacts/round_${ROUND_ID}_report.json"
    
    # Fetch round summary
    curl -s "http://localhost:8080/api/rounds/$ROUND_ID/summary" | jq '.' > "$report_file"
    
    # Display summary
    if [ -f "$report_file" ]; then
        echo ""
        echo "Round $ROUND_ID Summary:"
        echo "======================"
        jq -r '
            "Total Jobs: \(.total_jobs)",
            "Completed: \(.completed_jobs)",
            "Failed: \(.failed_jobs)",
            "Attack Success Rate: \(.attack_success_count)/\(.completed_jobs)",
            "Defense Detection Rate: \(.defense_success_count)/\(.completed_jobs)"
        ' "$report_file"
    fi
}

# Main execution
main() {
    log_info "Starting round $ROUND_ID with $NUM_JOBS jobs..."
    
    # Check services
    check_services
    
    # Submit jobs
    log_info "Submitting jobs..."
    for ((i=1; i<=NUM_JOBS; i++)); do
        local job_type=$([[ $((i % 2)) -eq 0 ]] && echo "DEFENSE" || echo "ATTACK")
        local job_spec=$(generate_job_spec $i "$job_type" $ROUND_ID)
        
        submit_job "$job_spec"
        echo -ne "\rSubmitted job $i/$NUM_JOBS"
    done
    echo ""
    
    # Run sandbox if available
    if [ -x "$PROJECT_ROOT/sandbox/scripts/run_sandbox.sh" ]; then
        run_sandbox_round
    fi
    
    # Monitor progress
    monitor_round
    
    # Generate report
    generate_report
    
    log_info "Round $ROUND_ID complete!"
    log_info "View results in dashboard: http://localhost:3000"
}

# Show usage
usage() {
    echo "Usage: $0 [ROUND_ID] [NUM_JOBS] [SEED_BASE]"
    echo "  ROUND_ID   - Round identifier (default: 1)"
    echo "  NUM_JOBS   - Number of jobs to create (default: 10)"
    echo "  SEED_BASE  - Base seed for deterministic execution (default: deadbeef)"
    echo ""
    echo "Example: $0 1 20 cafebabe"
}

# Parse arguments
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Run main
main