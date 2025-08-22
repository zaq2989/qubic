# API Reference

## REST API (Relay Service)

Base URL: `http://localhost:8080/api`

### Health Check

```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "workers": {
    "total": 10,
    "available": 8
  }
}
```

### Round Management

#### Get Round Summary

```http
GET /api/rounds/{round_id}/summary
```

**Response:**
```json
{
  "round_id": 1,
  "total_jobs": 100,
  "completed_jobs": 85,
  "failed_jobs": 5,
  "attack_success_count": 42,
  "defense_success_count": 38,
  "started_at": 1234567890,
  "ended_at": 1234568890
}
```

### Job Management

#### List Jobs

```http
GET /api/jobs?round={round_id}&status={status}
```

**Query Parameters:**
- `round` (optional): Filter by round ID
- `status` (optional): Filter by status (PENDING, IN_PROGRESS, COMPLETED, FAILED)

**Response:**
```json
[
  {
    "job_id": 123,
    "spec": {
      "round_id": 1,
      "job_type": "ATTACK",
      "seed": "deadbeef",
      "target_profile": "abcdef",
      "time_budget_ms": 5000
    },
    "status": "COMPLETED",
    "submitted_at": 1234567890,
    "completed_at": 1234567990,
    "result": {
      "hash": "sha256hash",
      "uri": "minio://artifacts/job-123/metrics.json",
      "signature": "ed25519signature"
    },
    "worker_id": "worker-1"
  }
]
```

#### Get Job Details

```http
GET /api/jobs/{job_id}
```

**Response:** Single job object (same as list item)

#### Get Job Metrics

```http
GET /api/job/{job_id}/metrics
```

**Response (Attack Job):**
```json
{
  "job_id": 123,
  "round_id": 1,
  "success": true,
  "exploit_time_ms": 812,
  "attempts": 3,
  "target_fingerprint": "nginx/1.18.0",
  "exploit_used": "CVE-2021-23017"
}
```

**Response (Defense Job):**
```json
{
  "job_id": 124,
  "round_id": 1,
  "detected": true,
  "true_positive_rate": 0.92,
  "false_positive_rate": 0.04,
  "alerts_generated": 15,
  "events_analyzed": 500
}
```

### Worker Management

#### List Workers

```http
GET /api/workers
```

**Response:**
```json
[
  {
    "id": "worker-1",
    "capabilities": {
      "job_types": ["ATTACK"],
      "max_concurrent_jobs": 2,
      "cpu_cores": 4,
      "memory_mb": 1024
    },
    "status": {
      "active_jobs": 1,
      "completed_jobs": 42,
      "cpu_usage": 0.65,
      "memory_usage": 0.45
    },
    "last_seen": "2024-01-15T10:30:00Z",
    "registered_at": "2024-01-15T08:00:00Z"
  }
]
```

## gRPC API (Worker Protocol)

Proto file: `worker.proto`

### Service Definition

```protobuf
service WorkerService {
  rpc Register(RegisterRequest) returns (RegisterResponse);
  rpc Heartbeat(HeartbeatRequest) returns (HeartbeatResponse);
  rpc GetJob(GetJobRequest) returns (GetJobResponse);
  rpc ReportResult(ReportResultRequest) returns (ReportResultResponse);
}
```

### Register Worker

**Request:**
```protobuf
message RegisterRequest {
  string worker_id = 1;
  WorkerCapabilities capabilities = 2;
}

message WorkerCapabilities {
  repeated string job_types = 1;
  uint32 max_concurrent_jobs = 2;
  uint32 cpu_cores = 3;
  uint64 memory_mb = 4;
}
```

**Response:**
```protobuf
message RegisterResponse {
  bool success = 1;
  string message = 2;
  string session_token = 3;
}
```

### Heartbeat

**Request:**
```protobuf
message HeartbeatRequest {
  string worker_id = 1;
  string session_token = 2;
  WorkerStatus status = 3;
}

message WorkerStatus {
  uint32 active_jobs = 1;
  uint32 completed_jobs = 2;
  float cpu_usage = 3;
  float memory_usage = 4;
}
```

### Get Job

**Request:**
```protobuf
message GetJobRequest {
  string worker_id = 1;
  string session_token = 2;
  repeated string preferred_types = 3;
}
```

**Response:**
```protobuf
message GetJobResponse {
  bool has_job = 1;
  Job job = 2;
}

message Job {
  uint32 job_id = 1;
  string job_type = 2;
  bytes seed = 3;
  bytes target_profile = 4;
  uint32 time_budget_ms = 5;
  uint32 round_id = 6;
}
```

### Report Result

**Request:**
```protobuf
message ReportResultRequest {
  string worker_id = 1;
  string session_token = 2;
  uint32 job_id = 3;
  ResultData result = 4;
}

message ResultData {
  bytes hash = 1;
  string uri = 2;
  bytes signature = 3;
  bool success = 4;
  uint32 execution_time_ms = 5;
}
```

## Storage API

### Upload Artifact

```bash
wargame-storage upload <local-file> <object-name>
```

### Download Artifact

```bash
wargame-storage download <object-name> <local-file>
```

### List Job Artifacts

```bash
wargame-storage list <job-id>
```

### Generate Presigned URL

```bash
wargame-storage presign <object-name> --expiry 1h
```

## Error Responses

All APIs use standard HTTP status codes:

- `200 OK` - Success
- `400 Bad Request` - Invalid parameters
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

Error Response Format:
```json
{
  "error": "Error message",
  "details": "Additional context"
}
```

## Rate Limiting

- REST API: 100 requests per minute per IP
- gRPC: 1000 RPCs per minute per worker
- Storage: 50 uploads per minute per worker

## Authentication

Current PoC uses session tokens for workers. Future versions will implement:
- JWT tokens for dashboard
- mTLS for worker connections
- API keys for external integrations