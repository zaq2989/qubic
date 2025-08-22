# Storage Module

MinIO-based storage client for managing Qubic Wargame Grid artifacts.

## Features

- Upload/download artifacts
- Job-based artifact organization
- Presigned URL generation
- Health checking
- CLI interface

## Configuration

Create `~/.wargame-storage.yaml`:

```yaml
endpoint: localhost:9000
access_key_id: minioadmin
secret_access_key: minioadmin
use_ssl: false
bucket_name: wargame-artifacts
```

Or use environment variables:
- `WARGAME_STORAGE_ENDPOINT`
- `WARGAME_STORAGE_ACCESS_KEY_ID`
- `WARGAME_STORAGE_SECRET_ACCESS_KEY`
- `WARGAME_STORAGE_USE_SSL`
- `WARGAME_STORAGE_BUCKET_NAME`

## Building

```bash
go build -o bin/wargame-storage ./src
```

## Usage

```bash
# Check storage health
wargame-storage health

# Upload an artifact
wargame-storage upload metrics.json jobs/123/metrics.json

# Download an artifact
wargame-storage download jobs/123/metrics.json output.json

# List job artifacts
wargame-storage list 123

# Generate presigned URL (1 hour expiry)
wargame-storage presign jobs/123/metrics.json --expiry 1h
```

## API Usage

```go
import "github.com/qubic/wargame-storage"

// Create client
cfg := &storage.Config{
    Endpoint: "localhost:9000",
    AccessKeyID: "minioadmin",
    SecretAccessKey: "minioadmin",
    BucketName: "wargame-artifacts",
}
client, err := storage.NewClient(cfg)

// Upload artifact
uri, err := client.UploadArtifact(ctx, "metrics.json", reader, size)

// Download artifact
reader, err := client.DownloadArtifact(ctx, "jobs/123/metrics.json")
```

## Artifact Organization

Artifacts are organized by job:
```
jobs/
├── 123/
│   ├── metrics.json
│   ├── replay.json
│   └── traffic.pcap
├── 124/
│   ├── metrics.json
│   └── replay.json
```