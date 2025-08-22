# Wargame Smart Contract

This directory contains the Qubic smart contract for the Cyber Wargame Grid.

## Overview

The contract manages:
- Job submission and tracking
- Result verification and recording
- Round management
- Reward calculation (simplified for PoC)

## Building

```bash
make
```

## Testing

```bash
make test
```

## Contract Functions

### Public Functions
- `submitJob(JobSpec)`: Submit a new attack/defense job
- `reportResult(job_id, digest, signature)`: Report job completion
- `finalizeRound(round_id)`: Finalize a round and calculate results

### View Functions
- `getJob(job_id)`: Get job details
- `getRoundSummary(round_id)`: Get round statistics
- `getCurrentRound()`: Get current round ID
- `isPaused()`: Check if contract is paused

### Admin Functions
- `pause()`: Emergency pause
- `unpause()`: Resume operations
- `startNewRound()`: Begin a new round