// SPDX-License-Identifier: MIT
use serde::{Deserialize, Serialize};

/// Defense metrics for reporting
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DefenseMetrics {
    pub job_id: u32,
    pub round_id: u32,
    pub detected: bool,
    pub true_positive_rate: f64,
    pub false_positive_rate: f64,
    pub alerts_generated: u32,
    pub events_analyzed: u32,
    pub detection_rules_matched: Vec<String>,
    pub timestamps: Vec<(String, u64)>,
}

/// Detection statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionStats {
    pub total_events: u32,
    pub malicious_events: u32,
    pub benign_events: u32,
    pub true_positives: u32,
    pub false_positives: u32,
    pub true_negatives: u32,
    pub false_negatives: u32,
}

impl DefenseMetrics {
    /// Create a summary of the defense analysis
    pub fn summary(&self) -> String {
        format!(
            "Job {}: {} - Analyzed {} events, generated {} alerts, TPR={:.2}, FPR={:.2}",
            self.job_id,
            if self.detected { "THREAT DETECTED" } else { "NO THREATS" },
            self.events_analyzed,
            self.alerts_generated,
            self.true_positive_rate,
            self.false_positive_rate
        )
    }
}

impl DetectionStats {
    /// Calculate precision (positive predictive value)
    pub fn precision(&self) -> f64 {
        if self.true_positives + self.false_positives == 0 {
            return 0.0;
        }
        self.true_positives as f64 / (self.true_positives + self.false_positives) as f64
    }
    
    /// Calculate recall (true positive rate)
    pub fn recall(&self) -> f64 {
        if self.true_positives + self.false_negatives == 0 {
            return 0.0;
        }
        self.true_positives as f64 / (self.true_positives + self.false_negatives) as f64
    }
    
    /// Calculate F1 score
    pub fn f1_score(&self) -> f64 {
        let precision = self.precision();
        let recall = self.recall();
        
        if precision + recall == 0.0 {
            return 0.0;
        }
        
        2.0 * (precision * recall) / (precision + recall)
    }
    
    /// Calculate accuracy
    pub fn accuracy(&self) -> f64 {
        let total = self.total_events as f64;
        if total == 0.0 {
            return 0.0;
        }
        
        let correct = (self.true_positives + self.true_negatives) as f64;
        correct / total
    }
}

/// Configuration replay information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DefenseReplayInfo {
    pub seed: String,
    pub job_id: u32,
    pub round_id: u32,
    pub detection_rules: Vec<String>,
    pub sensitivity_level: f32,
    pub container_config: DefenseContainerConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DefenseContainerConfig {
    pub image: String,
    pub cpu_limit: String,
    pub memory_limit: String,
    pub network_mode: String,
}

impl DefenseReplayInfo {
    /// Create replay info for a defense job
    pub fn new(job_id: u32, round_id: u32, seed: &[u8], sensitivity: f32) -> Self {
        Self {
            seed: hex::encode(seed),
            job_id,
            round_id,
            detection_rules: vec![
                "SQL_INJECTION".to_string(),
                "CMD_INJECTION".to_string(),
                "PATH_TRAVERSAL".to_string(),
                "PORT_SCAN".to_string(),
                "BRUTE_FORCE".to_string(),
            ],
            sensitivity_level: sensitivity,
            container_config: DefenseContainerConfig {
                image: "wargame/defender:v0.1".to_string(),
                cpu_limit: "1.0".to_string(),
                memory_limit: "512M".to_string(),
                network_mode: "monitor".to_string(),
            },
        }
    }
}