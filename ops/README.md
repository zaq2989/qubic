# Operations

This directory contains Docker Compose configurations and related files for running the complete Qubic Wargame Grid system.

## Quick Start

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

## Services

### Core Services
- **MinIO**: Object storage for artifacts (ports 9000, 9001)
- **Relay**: Job coordination service (ports 8080, 9090)
- **Dashboard**: Web UI (port 3000)
- **Qubic Node**: Mock blockchain node (port 10000)

### Workers
- **Attackers**: 2 attack workers
- **Defenders**: 2 defense workers

### Monitoring
- **Prometheus**: Metrics collection (port 9091)
- **Grafana**: Metrics visualization (port 3001)

## Configuration

Configuration files are in `config/`:
- `relay.yaml`: Relay service configuration
- `prometheus.yml`: Prometheus scraping configuration

## Networks

- `wargame-ops`: General operations network
- `wargame-blockchain`: Blockchain communication
- `wargame-sandbox`: Isolated network for workers (no external access)

## Volumes

Persistent data is stored in Docker volumes:
- `minio-data`: Object storage data
- `prometheus-data`: Metrics history
- `grafana-data`: Dashboard configurations

## Accessing Services

- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
- Dashboard: http://localhost:3000
- Relay API: http://localhost:8080/api/health
- Grafana: http://localhost:3001 (admin/admin)

## Scaling Workers

To add more workers:

```yaml
attacker-3:
  extends: attacker-1
  container_name: wargame-attacker-3
  environment:
    - WORKER_ID=attacker-3
```

## Production Considerations

For production deployment:
1. Use proper secrets management
2. Enable TLS for all services
3. Configure resource limits appropriately
4. Use external volumes for data persistence
5. Implement proper backup strategies