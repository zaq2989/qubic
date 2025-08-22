# Qubic Cyber Wargame Grid PoC

A proof-of-concept implementation of an AI-driven cybersecurity wargame on the Qubic L1 blockchain using uPoW jobs.

## Overview

This project implements attack and defense AI agents that compete in a sandboxed environment, with results recorded on-chain. The system ensures deterministic execution, complete network isolation, and reproducible results.

## Quick Start

```bash
# Setup environment
./scripts/setup.sh

# Run a test round
./scripts/run_round.sh

# Verify determinism
./scripts/assert_determinism.sh

# Check network isolation
./scripts/assert_no_egress.sh
```

## Architecture

- **Smart Contracts**: Job registration and result verification (C++)
- **Relay Service**: Worker-to-blockchain communication (Go)
- **Workers**: Attack and Defense AI implementations
- **Sandbox**: Isolated Docker/KVM environments
- **Storage**: MinIO for off-chain artifacts
- **Dashboard**: Web UI for monitoring

## Testing

```bash
# Unit tests
make test-unit

# Integration tests
make test-integration

# End-to-end tests
make test-e2e

# All tests
make test
```

## Documentation

See `/docs` for detailed documentation:
- [API Specification](docs/API.md)
- [Threat Model](docs/ThreatModel.md)
- [Architecture](docs/Architecture.md)

## License

SPDX-License-Identifier: MIT