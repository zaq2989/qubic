# Sandbox Environment

Isolated execution environment for running attack and defense simulations.

## Architecture

The sandbox consists of three containers:
- **Target**: Vulnerable services for testing
- **Attacker**: Executes attack simulations
- **Defender**: Monitors and analyzes traffic

## Network Isolation

- Internal bridge network with no external routing
- All containers communicate on isolated subnet (172.20.0.0/16)
- No internet access from sandbox containers
- Network monitoring for escape detection

## Security Features

- Capability dropping (minimal required caps)
- Seccomp profiles (relaxed for PoC)
- AppArmor/SELinux support
- Resource limits (CPU, memory, processes)
- Non-root execution where possible

## Usage

```bash
# Initial setup
./scripts/run_sandbox.sh setup

# Run a round
./scripts/run_sandbox.sh run <round_id> <job_spec_json>

# Monitor for escapes
./scripts/run_sandbox.sh monitor

# Cleanup
./scripts/run_sandbox.sh cleanup
```

## Vulnerable Services

The target container includes intentionally vulnerable services:
- Apache with vulnerable PHP app (SQL injection, command injection, etc.)
- SSH with weak credentials
- MySQL with test database
- Simple echo server

## Artifact Collection

After each round, artifacts are collected:
- Attack metrics and logs
- Defense analysis results
- Network packet captures
- Container logs

## Safety Notes

- This is a PoC implementation with simplified isolation
- Do not run on production systems
- Always verify network isolation before running
- Monitor for container escapes during execution