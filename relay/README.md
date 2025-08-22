# Wargame Relay Service

The relay service manages communication between workers and the Qubic blockchain.

## Features

- Job scheduling and distribution
- Worker registration and management
- Result collection and verification
- HTTP API for monitoring
- gRPC interface for workers

## Configuration

Configuration is handled via `config.yaml` or environment variables:

```yaml
server:
  http_port: 8080
  grpc_port: 9090

blockchain:
  endpoint: localhost:10000

worker:
  pool_size: 10

log:
  level: info
```

## Building

```bash
# Generate protobuf code
protoc --go_out=. --go-grpc_out=. src/worker/worker.proto

# Build the service
go build -o bin/relay ./src
```

## Running

```bash
./bin/relay
```

## API Endpoints

- `GET /api/health` - Health check
- `GET /api/jobs` - List jobs
- `GET /api/jobs/{id}` - Get job details
- `GET /api/workers` - List connected workers
- `GET /api/rounds/{id}/summary` - Get round summary

## Worker Protocol

Workers connect via gRPC on port 9090:

1. Register with capabilities
2. Send periodic heartbeats
3. Request job assignments
4. Report results