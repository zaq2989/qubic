# Architecture

## System Overview

The Qubic Cyber Wargame Grid follows a distributed architecture designed for scalability, security, and determinism.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Qubic L1      │     │  Relay Service  │     │   Dashboard     │
│  Blockchain     │◄────┤   (Go/gRPC)     ├────►│  (Next.js)      │
└────────┬────────┘     └────────┬────────┘     └─────────────────┘
         │                       │
         │              ┌────────┴────────┐
         │              │                 │
    ┌────▼────┐    ┌────▼────┐      ┌────▼────┐
    │ Smart   │    │ Attack  │      │ Defense │
    │Contract │    │ Worker  │      │ Worker  │
    └─────────┘    └─────────┘      └─────────┘
                        │                 │
                        └────────┬────────┘
                                 │
                         ┌───────▼───────┐
                         │   Sandbox     │
                         │ Environment   │
                         └───────────────┘
```

## Components

### 1. Blockchain Layer

**Smart Contracts** (C++)
- Job registration and lifecycle management
- Result verification using Ed25519 signatures
- Round orchestration and statistics
- Emergency pause functionality

Key Functions:
- `submitJob(JobSpec)` - Register new job
- `reportResult(job_id, digest, signature)` - Submit results
- `finalizeRound(round_id)` - Complete round

### 2. Relay Service

**Purpose**: Bridge between blockchain and workers

**Technology**: Go with gRPC and HTTP APIs

**Responsibilities**:
- Worker pool management
- Job scheduling and distribution
- Result collection and verification
- HTTP API for dashboard

**APIs**:
- gRPC for worker communication
- REST API for dashboard/monitoring

### 3. Workers

#### Attack Worker (Rust)
- Deterministic attack simulation
- Port scanning
- Service fingerprinting
- Exploit execution
- Metrics generation

#### Defense Worker (Rust)
- Traffic analysis
- Rule-based detection
- Behavioral analysis
- Alert generation
- Performance metrics

### 4. Sandbox Environment

**Technology**: Docker with network isolation

**Components**:
- Target container (vulnerable services)
- Attacker container
- Defender container
- Isolated bridge network

**Security**:
- No external network access
- Resource limits
- Capability restrictions
- Snapshot/restore functionality

### 5. Storage Layer

**Technology**: MinIO (S3-compatible)

**Data Organization**:
```
artifacts/
├── jobs/
│   ├── 123/
│   │   ├── metrics.json
│   │   ├── replay.json
│   │   └── traffic.pcap
│   └── 124/
│       └── ...
└── rounds/
    └── 1/
        └── summary.json
```

### 6. Dashboard

**Technology**: Next.js with TypeScript

**Features**:
- Real-time updates (5s polling)
- Round overview
- Job tracking
- Worker monitoring
- Performance visualization

## Data Flow

1. **Job Submission**
   ```
   User → Dashboard → Relay → Blockchain
   ```

2. **Job Execution**
   ```
   Blockchain → Relay → Worker → Sandbox → Storage
   ```

3. **Result Reporting**
   ```
   Worker → Relay → Blockchain → Dashboard
   ```

## Determinism Design

### Seed-Based Randomness
- All randomness derived from job seed
- ChaCha8 PRNG for consistent sequences
- No system time dependencies
- No external data sources

### Execution Isolation
- Fixed container images
- Disabled network access
- Resource limits
- Snapshot restoration

### Verification
- Result hashing (SHA-256)
- Ed25519 signatures
- Replay capability

## Scalability

### Horizontal Scaling
- Multiple relay instances
- Worker pool expansion
- Distributed storage

### Performance Optimizations
- Concurrent job execution
- Batch result reporting
- Efficient artifact storage

## Security Architecture

### Defense in Depth
1. **Container Security**
   - Minimal privileges
   - Capability dropping
   - Seccomp profiles

2. **Network Security**
   - Internal-only networks
   - No NAT/routing
   - Traffic monitoring

3. **Application Security**
   - Input validation
   - Signature verification
   - Rate limiting

### Trust Model
- Workers are untrusted
- Results require cryptographic proof
- Blockchain provides consensus
- Storage provides availability

## Deployment Architecture

### Development
```
Local Machine
├── Relay (localhost:8080)
├── Workers (localhost)
├── MinIO (localhost:9000)
└── Dashboard (localhost:3000)
```

### Production
```
Kubernetes Cluster
├── Relay Deployment (3 replicas)
├── Worker DaemonSet
├── MinIO StatefulSet
└── Dashboard Deployment
```

## Monitoring and Observability

### Metrics
- Job completion rates
- Worker utilization
- Attack success rates
- Defense detection rates

### Logging
- Structured JSON logs
- Correlation IDs
- Centralized aggregation

### Tracing
- Distributed tracing support
- Job lifecycle tracking
- Performance profiling