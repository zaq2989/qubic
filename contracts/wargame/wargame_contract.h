// SPDX-License-Identifier: MIT
#pragma once

#include <cstdint>
#include <array>
#include <cstring>

namespace QubicWargame {

// Constants
constexpr uint32_t MAX_JOBS_PER_ROUND = 100;
constexpr uint32_t MAX_WORKERS = 50;
constexpr uint32_t DIGEST_SIZE = 32;
constexpr uint32_t SIGNATURE_SIZE = 64;
constexpr uint32_t URI_MAX_LENGTH = 256;

// Enums
enum class JobType : uint8_t {
    ATTACK = 0,
    DEFENSE = 1
};

enum class JobStatus : uint8_t {
    PENDING = 0,
    IN_PROGRESS = 1,
    COMPLETED = 2,
    FAILED = 3
};

// Structures
struct JobSpec {
    uint32_t round_id;
    JobType job_type;
    std::array<uint8_t, 32> seed;
    std::array<uint8_t, 32> target_profile;
    uint32_t time_budget_ms;
};

struct ResultDigest {
    std::array<uint8_t, DIGEST_SIZE> hash;
    char uri[URI_MAX_LENGTH];
    std::array<uint8_t, SIGNATURE_SIZE> signature;
};

struct JobRecord {
    uint32_t job_id;
    JobSpec spec;
    JobStatus status;
    uint64_t submitted_at;
    uint64_t completed_at;
    ResultDigest result;
    std::array<uint8_t, 32> worker_id;
};

struct RoundSummary {
    uint32_t round_id;
    uint32_t total_jobs;
    uint32_t completed_jobs;
    uint32_t failed_jobs;
    uint32_t attack_success_count;
    uint32_t defense_success_count;
    uint64_t started_at;
    uint64_t ended_at;
};

// Contract Interface
class WargameContract {
private:
    // State variables
    uint32_t current_round_id;
    uint32_t next_job_id;
    bool is_paused;
    
    // Storage
    JobRecord jobs[MAX_JOBS_PER_ROUND];
    RoundSummary rounds[100];
    
    // Helper functions
    bool verifySignature(const ResultDigest& digest, const std::array<uint8_t, 32>& worker_id);
    bool validateJobSpec(const JobSpec& spec);
    uint32_t calculateReward(const JobRecord& job);

public:
    // Constructor
    WargameContract();
    
    // Public functions
    uint32_t submitJob(const JobSpec& spec);
    bool reportResult(uint32_t job_id, const ResultDigest& digest, const std::array<uint8_t, SIGNATURE_SIZE>& signature);
    RoundSummary finalizeRound(uint32_t round_id);
    
    // View functions
    JobRecord getJob(uint32_t job_id) const;
    RoundSummary getRoundSummary(uint32_t round_id) const;
    uint32_t getCurrentRound() const { return current_round_id; }
    bool isPaused() const { return is_paused; }
    
    // Admin functions
    void pause();
    void unpause();
    void startNewRound();
};

} // namespace QubicWargame