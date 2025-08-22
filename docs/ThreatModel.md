# Threat Model

## Overview

This document outlines the security threats, mitigations, and design decisions for the Qubic Cyber Wargame Grid.

## System Boundaries

### In Scope
- Worker containers and sandbox environment
- Relay service and APIs
- Storage system (MinIO)
- Smart contract interactions
- Dashboard web application

### Out of Scope
- Qubic L1 blockchain security
- Physical security of infrastructure
- Social engineering attacks
- Supply chain attacks (for PoC)

## Assets

### Primary Assets
1. **Blockchain State** - Job records, results, round data
2. **Worker Credentials** - Session tokens, signing keys
3. **Artifact Data** - Metrics, replays, packet captures
4. **System Integrity** - Deterministic execution guarantee

### Secondary Assets
1. **Compute Resources** - CPU, memory, storage
2. **Network Bandwidth** - Inter-component communication
3. **Logs and Metrics** - Operational data

## Threat Actors

1. **Malicious Workers** - Compromised or rogue worker nodes
2. **External Attackers** - Internet-based adversaries
3. **Malicious Users** - Authorized users with bad intent
4. **Compromised Containers** - Escaped sandbox processes

## Threats and Mitigations

### T1: Container Escape

**Description**: Attacker breaks out of container isolation

**Impact**: High - Host system compromise

**Mitigations**:
- Minimal container privileges (drop ALL capabilities)
- Seccomp profiles restricting syscalls
- AppArmor/SELinux enforcement
- Regular security updates
- Resource limits (CPU, memory, PIDs)

### T2: Network Egress

**Description**: Containers communicate with external networks

**Impact**: High - Data exfiltration, command & control

**Mitigations**:
- Internal-only Docker networks
- No NAT or routing to external networks
- Network monitoring with tcpdump
- Firewall rules blocking outbound traffic
- Regular egress testing

### T3: Result Manipulation

**Description**: Worker reports false results

**Impact**: Medium - Incorrect blockchain state

**Mitigations**:
- Ed25519 signature verification
- Deterministic execution verification
- Multiple worker consensus (future)
- Result replay capability

### T4: Resource Exhaustion

**Description**: DoS through excessive resource consumption

**Impact**: Medium - Service disruption

**Mitigations**:
- Container resource limits
- Job time budgets
- Worker pool size limits
- Rate limiting on APIs
- Monitoring and alerting

### T5: Data Tampering

**Description**: Modification of stored artifacts

**Impact**: Low - Integrity violation

**Mitigations**:
- SHA-256 content hashing
- Signed references on blockchain
- MinIO access controls
- Audit logging

### T6: Information Disclosure

**Description**: Unauthorized access to sensitive data

**Impact**: Medium - Privacy violation

**Mitigations**:
- TLS for API communications
- Authentication tokens
- Least privilege access
- No sensitive data in logs

### T7: Replay Attacks

**Description**: Resubmission of valid old results

**Impact**: Low - Stale data

**Mitigations**:
- Timestamp validation
- Nonce in job specifications
- Job ID uniqueness checks

### T8: Sandbox Fingerprinting

**Description**: Detecting sandbox environment

**Impact**: Low - Evasion techniques

**Mitigations**:
- Realistic service simulation
- Timing variance injection
- Hardware characteristic masking

## Security Controls

### Preventive Controls

1. **Network Isolation**
   ```yaml
   networks:
     wargame-net:
       internal: true  # No external routing
   ```

2. **Container Security**
   ```yaml
   security_opt:
     - no-new-privileges:true
     - seccomp:unconfined  # Custom profile in production
   cap_drop:
     - ALL
   ```

3. **Input Validation**
   - Seed format validation
   - Job specification limits
   - API parameter sanitization

### Detective Controls

1. **Monitoring**
   - Container escape detection
   - Network traffic analysis
   - Resource usage tracking

2. **Logging**
   - Audit trails for all operations
   - Failed authentication attempts
   - Anomaly detection

3. **Testing**
   - Regular security scans
   - Penetration testing
   - Determinism verification

### Corrective Controls

1. **Incident Response**
   - Emergency pause functionality
   - Container termination
   - Worker blacklisting

2. **Recovery**
   - Snapshot restoration
   - Result verification
   - Round rollback capability

## Security Architecture Decisions

### Defense in Depth
Multiple layers of security controls to prevent single point of failure.

### Least Privilege
Each component has minimal required permissions.

### Zero Trust
No implicit trust between components; all interactions authenticated.

### Fail Secure
System fails to a secure state on errors.

## Compliance Considerations

### Data Protection
- No PII storage
- Minimal data retention
- Right to deletion support

### Audit Requirements
- Complete audit trail
- Immutable blockchain records
- Regular security assessments

## Security Testing

### Regular Tests
1. Container escape attempts
2. Network isolation verification
3. Resource exhaustion scenarios
4. Authentication bypass attempts

### Tools
- Docker Bench Security
- Network scanners (nmap)
- Static analysis (CodeQL)
- Dynamic analysis (fuzzing)

## Future Improvements

1. **Hardware Security**
   - SGX enclaves for workers
   - HSM for key management

2. **Advanced Monitoring**
   - ML-based anomaly detection
   - Real-time threat intelligence

3. **Formal Verification**
   - Smart contract verification
   - Protocol correctness proofs

## Incident Response Plan

1. **Detection** - Automated alerts
2. **Containment** - Isolate affected components
3. **Eradication** - Remove threat
4. **Recovery** - Restore normal operations
5. **Lessons Learned** - Update controls

## Security Contacts

- Security Team: security@qubic.example
- Bug Bounty: https://qubic.example/security
- Incident Response: incident@qubic.example