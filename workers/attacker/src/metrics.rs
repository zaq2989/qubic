// SPDX-License-Identifier: MIT
use serde::{Deserialize, Serialize};

/// Attack metrics for reporting
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttackMetrics {
    pub job_id: u32,
    pub round_id: u32,
    pub success: bool,
    pub exploit_time_ms: u64,
    pub attempts: u32,
    pub target_fingerprint: String,
    pub exploit_used: String,
    pub timestamps: Vec<(String, u64)>,
}

/// Replay information for reproducing the attack
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReplayInfo {
    pub seed: String,
    pub job_id: u32,
    pub round_id: u32,
    pub target_profile: String,
    pub container_images: ContainerImages,
    pub execution_params: ExecutionParams,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerImages {
    pub attacker: String,
    pub defender: String,
    pub target: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionParams {
    pub time_budget_ms: u32,
    pub cpu_limit: String,
    pub memory_limit: String,
}

impl AttackMetrics {
    /// Create a summary of the attack
    pub fn summary(&self) -> String {
        format!(
            "Job {}: {} in {}ms after {} attempts using {}",
            self.job_id,
            if self.success { "SUCCESS" } else { "FAILED" },
            self.exploit_time_ms,
            self.attempts,
            if self.success { &self.exploit_used } else { "none" }
        )
    }
}

impl ReplayInfo {
    /// Create replay info for a job
    pub fn new(job_id: u32, round_id: u32, seed: &[u8], target_profile: &[u8]) -> Self {
        Self {
            seed: hex::encode(seed),
            job_id,
            round_id,
            target_profile: hex::encode(target_profile),
            container_images: ContainerImages {
                attacker: "wargame/attacker:v0.1".to_string(),
                defender: "wargame/defender:v0.1".to_string(),
                target: "wargame/vuln-target:v0.1".to_string(),
            },
            execution_params: ExecutionParams {
                time_budget_ms: 5000,
                cpu_limit: "1.0".to_string(),
                memory_limit: "512M".to_string(),
            },
        }
    }
}