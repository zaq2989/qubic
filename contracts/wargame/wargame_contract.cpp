// SPDX-License-Identifier: MIT
#include "wargame_contract.h"
#include <algorithm>

namespace QubicWargame {

WargameContract::WargameContract() 
    : current_round_id(0), next_job_id(0), is_paused(false) {
    // Initialize storage
    std::memset(jobs, 0, sizeof(jobs));
    std::memset(rounds, 0, sizeof(rounds));
}

uint32_t WargameContract::submitJob(const JobSpec& spec) {
    // Check if contract is paused
    if (is_paused) {
        return 0; // Invalid job ID
    }
    
    // Validate job specification
    if (!validateJobSpec(spec)) {
        return 0;
    }
    
    // Check if we have space for more jobs
    if (next_job_id >= MAX_JOBS_PER_ROUND) {
        return 0;
    }
    
    // Create new job record
    uint32_t job_id = next_job_id++;
    JobRecord& job = jobs[job_id];
    
    job.job_id = job_id;
    job.spec = spec;
    job.status = JobStatus::PENDING;
    job.submitted_at = /* current block timestamp */0; // Placeholder
    job.completed_at = 0;
    
    // Emit event (in real implementation)
    // emit JobSubmitted(job_id, spec.job_type, spec.round_id);
    
    return job_id;
}

bool WargameContract::reportResult(uint32_t job_id, const ResultDigest& digest, 
                                  const std::array<uint8_t, SIGNATURE_SIZE>& signature) {
    // Validate job ID
    if (job_id >= next_job_id) {
        return false;
    }
    
    JobRecord& job = jobs[job_id];
    
    // Check job status
    if (job.status != JobStatus::PENDING && job.status != JobStatus::IN_PROGRESS) {
        return false;
    }
    
    // Verify signature
    if (!verifySignature(digest, job.worker_id)) {
        return false;
    }
    
    // Update job record
    job.result = digest;
    job.status = JobStatus::COMPLETED;
    job.completed_at = /* current block timestamp */0; // Placeholder
    
    // Update round statistics
    RoundSummary& round = rounds[job.spec.round_id];
    round.completed_jobs++;
    
    // Parse result to determine success (simplified for PoC)
    // In real implementation, would decode metrics.json from off-chain storage
    bool is_success = (digest.hash[0] & 0x01) == 1; // Simplified success check
    
    if (job.spec.job_type == JobType::ATTACK && is_success) {
        round.attack_success_count++;
    } else if (job.spec.job_type == JobType::DEFENSE && is_success) {
        round.defense_success_count++;
    }
    
    // Emit event
    // emit ResultAccepted(job_id, digest.hash, digest.uri);
    
    return true;
}

RoundSummary WargameContract::finalizeRound(uint32_t round_id) {
    // Validate round ID
    if (round_id > current_round_id) {
        return RoundSummary{};
    }
    
    RoundSummary& round = rounds[round_id];
    
    // Mark any pending jobs as failed
    for (uint32_t i = 0; i < next_job_id; i++) {
        if (jobs[i].spec.round_id == round_id && 
            jobs[i].status == JobStatus::PENDING) {
            jobs[i].status = JobStatus::FAILED;
            round.failed_jobs++;
        }
    }
    
    // Update round end time
    round.ended_at = /* current block timestamp */0; // Placeholder
    
    // Emit event
    // emit RoundFinalized(round_id, round);
    
    return round;
}

JobRecord WargameContract::getJob(uint32_t job_id) const {
    if (job_id >= next_job_id) {
        return JobRecord{};
    }
    return jobs[job_id];
}

RoundSummary WargameContract::getRoundSummary(uint32_t round_id) const {
    if (round_id >= 100) {
        return RoundSummary{};
    }
    return rounds[round_id];
}

void WargameContract::pause() {
    // Only admin can pause (check would be done by Qubic runtime)
    is_paused = true;
    // emit ContractPaused();
}

void WargameContract::unpause() {
    // Only admin can unpause
    is_paused = false;
    // emit ContractUnpaused();
}

void WargameContract::startNewRound() {
    // Finalize current round if needed
    if (current_round_id < 100) {
        finalizeRound(current_round_id);
    }
    
    // Start new round
    current_round_id++;
    next_job_id = 0; // Reset job counter for new round
    
    RoundSummary& new_round = rounds[current_round_id];
    new_round.round_id = current_round_id;
    new_round.started_at = /* current block timestamp */0; // Placeholder
    new_round.total_jobs = 0;
    new_round.completed_jobs = 0;
    new_round.failed_jobs = 0;
    new_round.attack_success_count = 0;
    new_round.defense_success_count = 0;
    
    // emit NewRoundStarted(current_round_id);
}

// Helper functions
bool WargameContract::verifySignature(const ResultDigest& digest, 
                                     const std::array<uint8_t, 32>& worker_id) {
    // Simplified signature verification for PoC
    // In real implementation, would use Ed25519 verification
    return digest.signature[0] != 0; // Placeholder
}

bool WargameContract::validateJobSpec(const JobSpec& spec) {
    // Validate round ID
    if (spec.round_id != current_round_id) {
        return false;
    }
    
    // Validate time budget
    if (spec.time_budget_ms == 0 || spec.time_budget_ms > 60000) { // Max 60 seconds
        return false;
    }
    
    // Validate seed is not empty
    bool seed_empty = true;
    for (auto b : spec.seed) {
        if (b != 0) {
            seed_empty = false;
            break;
        }
    }
    
    return !seed_empty;
}

uint32_t WargameContract::calculateReward(const JobRecord& job) {
    // Simplified reward calculation for PoC
    if (job.status == JobStatus::COMPLETED) {
        return 100; // Base reward in QUs
    }
    return 0;
}

} // namespace QubicWargame