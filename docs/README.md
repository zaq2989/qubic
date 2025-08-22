# Qubic Cyber Wargame Grid Documentation

## Overview

The Qubic Cyber Wargame Grid is a proof-of-concept implementation of an AI-driven cybersecurity simulation platform built on the Qubic L1 blockchain. It enables deterministic execution of attack and defense AI agents in isolated environments with results recorded on-chain.

## Table of Contents

1. [Architecture](Architecture.md) - System design and components
2. [API Reference](API.md) - REST and gRPC API documentation
3. [Threat Model](ThreatModel.md) - Security considerations
4. [Development Guide](Development.md) - Setup and development workflow
5. [Deployment Guide](Deployment.md) - Production deployment instructions

## Quick Start

```bash
# Clone repository
git clone https://github.com/qubic/wargame-grid
cd qubic-wargame-grid

# Run setup
./scripts/setup.sh

# Start services
cd relay && ./bin/relay &
cd dashboard && npm run dev &

# Run a test round
./scripts/run_round.sh
```

## Key Features

- **Deterministic Execution**: Same seed produces identical results
- **Network Isolation**: Complete sandbox isolation from external networks
- **Blockchain Integration**: Job management and result verification on Qubic L1
- **Scalable Architecture**: Distributed worker pool with gRPC communication
- **Real-time Monitoring**: Web dashboard for round tracking

## Component Overview

### Smart Contracts
- Job registration and management
- Result verification
- Round orchestration

### Relay Service
- Worker coordination
- Job scheduling
- Blockchain communication

### Workers
- **Attack Worker**: Simulates cyber attacks
- **Defense Worker**: Monitors and detects threats

### Storage
- MinIO-based artifact storage
- Metrics and replay data

### Dashboard
- Real-time monitoring
- Performance visualization
- Job tracking

## Security

The system implements multiple layers of security:
- Container isolation with capability dropping
- Network segmentation
- Deterministic execution for verification
- Signed results with Ed25519

See [Threat Model](ThreatModel.md) for detailed security analysis.

## Testing

Run the complete test suite:

```bash
./tests/run_tests.sh all
```

Test categories:
- Unit tests
- Integration tests
- End-to-end tests
- Determinism verification
- Network isolation checks

## Contributing

Please see [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

SPDX-License-Identifier: MIT