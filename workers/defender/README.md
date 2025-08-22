# Defense Worker

Deterministic defense simulation worker for the Qubic Cyber Wargame Grid.

## Features

- Deterministic traffic analysis based on seed
- Rule-based detection (Snort/Sigma style)
- Behavioral pattern analysis
- Metrics collection and reporting
- Configurable sensitivity levels

## Building

```bash
cargo build --release
```

## Running

```bash
cargo run -- --relay-endpoint http://localhost:9090 --worker-id defender-1
```

## Command Line Options

- `--relay-endpoint`: Relay service endpoint (default: http://localhost:9090)
- `--worker-id`: Unique worker identifier (default: defender-1)
- `--max-concurrent-jobs`: Maximum concurrent jobs (default: 2)

## Detection Capabilities

### Rule-Based Detection
- SQL Injection patterns
- Command Injection attempts
- Path Traversal attacks
- Cross-Site Scripting (XSS)
- Port scanning activity

### Behavioral Analysis
- Connection flood detection
- Brute force attack detection
- Anomalous traffic patterns

## Metrics

The defender reports:
- True Positive Rate (TPR)
- False Positive Rate (FPR)
- Number of alerts generated
- Detection rules matched
- Timeline of detections

## Determinism

All analysis is seeded from the job's seed value, ensuring:
- Same seed + same traffic = same detection results
- Reproducible alert generation
- Consistent sensitivity thresholds