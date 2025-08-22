# Attack Worker

Deterministic attack simulation worker for the Qubic Cyber Wargame Grid.

## Features

- Deterministic execution based on seed
- Port scanning simulation
- Service fingerprinting
- Exploit selection and execution
- Metrics collection and reporting

## Building

```bash
cargo build --release
```

## Running

```bash
cargo run -- --relay-endpoint http://localhost:9090 --worker-id attacker-1
```

## Command Line Options

- `--relay-endpoint`: Relay service endpoint (default: http://localhost:9090)
- `--worker-id`: Unique worker identifier (default: attacker-1)
- `--max-concurrent-jobs`: Maximum concurrent jobs (default: 2)

## Attack Phases

1. **Port Scanning**: Deterministic port discovery based on target profile
2. **Service Fingerprinting**: Identify services on open ports
3. **Exploit Selection**: Choose appropriate exploits for identified services
4. **Exploit Execution**: Attempt exploits in order of likelihood

## Determinism

All randomness is seeded from the job's seed value, ensuring:
- Same seed + same target = same result
- Reproducible attack sequences
- Verifiable outcomes