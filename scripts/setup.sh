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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        missing+=("docker-compose")
    fi
    
    # Check Go
    if ! command -v go &> /dev/null; then
        missing+=("go")
    fi
    
    # Check Rust
    if ! command -v cargo &> /dev/null; then
        missing+=("rust/cargo")
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        missing+=("node.js")
    fi
    
    # Check protoc
    if ! command -v protoc &> /dev/null; then
        missing+=("protobuf-compiler")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing prerequisites: ${missing[*]}"
        log_error "Please install missing dependencies and run setup again"
        exit 1
    fi
    
    log_info "All prerequisites satisfied"
}

# Setup MinIO
setup_minio() {
    log_info "Setting up MinIO..."
    
    docker run -d \
        --name minio \
        -p 9000:9000 \
        -p 9001:9001 \
        -e MINIO_ROOT_USER=minioadmin \
        -e MINIO_ROOT_PASSWORD=minioadmin \
        -v minio-data:/data \
        minio/minio server /data --console-address ":9001" \
        || log_warn "MinIO container already exists"
    
    # Wait for MinIO to start
    sleep 5
    
    # Create bucket
    docker exec minio mc alias set local http://localhost:9000 minioadmin minioadmin || true
    docker exec minio mc mb local/wargame-artifacts || true
    
    log_info "MinIO setup complete (console: http://localhost:9001)"
}

# Build contracts
build_contracts() {
    log_info "Building smart contracts..."
    cd "$PROJECT_ROOT/contracts/wargame"
    make clean && make
    cd "$PROJECT_ROOT"
}

# Build relay service
build_relay() {
    log_info "Building relay service..."
    cd "$PROJECT_ROOT/relay"
    
    # Generate protobuf code
    protoc --go_out=. --go-grpc_out=. src/worker/worker.proto || true
    
    # Build binary
    go build -o bin/relay ./src
    cd "$PROJECT_ROOT"
}

# Build workers
build_workers() {
    log_info "Building attack worker..."
    cd "$PROJECT_ROOT/workers/attacker"
    cargo build --release
    
    log_info "Building defense worker..."
    cd "$PROJECT_ROOT/workers/defender"
    cargo build --release
    
    cd "$PROJECT_ROOT"
}

# Build storage CLI
build_storage() {
    log_info "Building storage CLI..."
    cd "$PROJECT_ROOT/storage"
    go build -o bin/wargame-storage ./src
    cd "$PROJECT_ROOT"
}

# Setup dashboard
setup_dashboard() {
    log_info "Setting up dashboard..."
    cd "$PROJECT_ROOT/dashboard"
    npm install
    cd "$PROJECT_ROOT"
}

# Build Docker images
build_docker_images() {
    log_info "Building Docker images..."
    
    # Build sandbox images
    docker build -f sandbox/docker/Dockerfile.attacker -t wargame/attacker:v0.1 .
    docker build -f sandbox/docker/Dockerfile.defender -t wargame/defender:v0.1 .
    docker build -f sandbox/docker/Dockerfile.target -t wargame/target:v0.1 .
}

# Create directories
create_directories() {
    log_info "Creating required directories..."
    mkdir -p "$PROJECT_ROOT/artifacts"
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/tmp"
}

# Generate config files
generate_configs() {
    log_info "Generating configuration files..."
    
    # Relay config
    cat > "$PROJECT_ROOT/relay/config.yaml" <<EOF
server:
  http_port: 8080
  grpc_port: 9090

blockchain:
  endpoint: localhost:10000

worker:
  pool_size: 10

log:
  level: info
EOF

    # Storage config
    cat > "$HOME/.wargame-storage.yaml" <<EOF
endpoint: localhost:9000
access_key_id: minioadmin
secret_access_key: minioadmin
use_ssl: false
bucket_name: wargame-artifacts
EOF

    # Dashboard env
    cat > "$PROJECT_ROOT/dashboard/.env.local" <<EOF
NEXT_PUBLIC_API_URL=http://localhost:8080/api
RELAY_API_URL=http://localhost:8080/api
EOF
}

# Main setup
main() {
    log_info "Starting Qubic Wargame Grid setup..."
    
    check_prerequisites
    create_directories
    
    # Core components
    setup_minio
    build_contracts
    build_relay
    build_workers
    build_storage
    setup_dashboard
    
    # Docker images
    build_docker_images
    
    # Configurations
    generate_configs
    
    # Sandbox setup
    "$PROJECT_ROOT/sandbox/scripts/run_sandbox.sh" setup
    
    log_info "Setup complete!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Start the relay service: cd relay && ./bin/relay"
    log_info "2. Start the dashboard: cd dashboard && npm run dev"
    log_info "3. Run a test round: ./scripts/run_round.sh"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi