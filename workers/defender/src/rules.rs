// SPDX-License-Identifier: MIT
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::sync::OnceLock;

static RULE_ENGINE: OnceLock<RuleEngine> = OnceLock::new();

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionRule {
    pub id: String,
    pub name: String,
    pub description: String,
    pub severity: u8,
    pub is_malicious: bool,
    pub protocol: Option<String>,
    pub port: Option<u16>,
    pub pattern: Option<String>,
    pub keywords: Vec<String>,
}

pub struct RuleEngine {
    pub rules: Vec<DetectionRule>,
}

impl RuleEngine {
    pub fn new() -> Self {
        Self {
            rules: get_default_rules(),
        }
    }
    
    pub fn add_rule(&mut self, rule: DetectionRule) {
        self.rules.push(rule);
    }
}

pub fn load_default_rules() -> Result<()> {
    let engine = RuleEngine::new();
    RULE_ENGINE.set(engine).map_err(|_| anyhow::anyhow!("Failed to initialize rule engine"))?;
    Ok(())
}

fn get_default_rules() -> Vec<DetectionRule> {
    vec![
        // SQL Injection rules
        DetectionRule {
            id: "SQL_INJECTION_1".to_string(),
            name: "SQL Injection - UNION".to_string(),
            description: "Detected UNION-based SQL injection attempt".to_string(),
            severity: 9,
            is_malicious: true,
            protocol: Some("HTTP".to_string()),
            port: None,
            pattern: Some(r"(?i)(union\s+select|union\s+all\s+select)".to_string()),
            keywords: vec!["UNION".to_string(), "SELECT".to_string()],
        },
        DetectionRule {
            id: "SQL_INJECTION_2".to_string(),
            name: "SQL Injection - OR 1=1".to_string(),
            description: "Detected classic SQL injection pattern".to_string(),
            severity: 9,
            is_malicious: true,
            protocol: Some("HTTP".to_string()),
            port: None,
            pattern: Some(r"(?i)(or\s+1\s*=\s*1|or\s+'1'\s*=\s*'1')".to_string()),
            keywords: vec!["OR".to_string(), "1=1".to_string()],
        },
        
        // Command Injection rules
        DetectionRule {
            id: "CMD_INJECTION_1".to_string(),
            name: "Command Injection - Shell".to_string(),
            description: "Detected shell command injection attempt".to_string(),
            severity: 10,
            is_malicious: true,
            protocol: Some("HTTP".to_string()),
            port: None,
            pattern: Some(r"(?i)(;|&&|\|\|)\s*(cat|ls|wget|curl|nc|bash|sh)".to_string()),
            keywords: vec![],
        },
        DetectionRule {
            id: "CMD_INJECTION_2".to_string(),
            name: "Command Injection - Backticks".to_string(),
            description: "Detected command substitution attempt".to_string(),
            severity: 10,
            is_malicious: true,
            protocol: None,
            port: None,
            pattern: Some(r"`[^`]+`|\$\([^\)]+\)".to_string()),
            keywords: vec![],
        },
        
        // Path Traversal rules
        DetectionRule {
            id: "PATH_TRAVERSAL_1".to_string(),
            name: "Path Traversal - Dot Dot".to_string(),
            description: "Detected directory traversal attempt".to_string(),
            severity: 8,
            is_malicious: true,
            protocol: Some("HTTP".to_string()),
            port: None,
            pattern: Some(r"\.\.\/|\.\.\\".to_string()),
            keywords: vec!["../".to_string(), "..\\".to_string()],
        },
        DetectionRule {
            id: "PATH_TRAVERSAL_2".to_string(),
            name: "Path Traversal - etc/passwd".to_string(),
            description: "Attempt to access sensitive system files".to_string(),
            severity: 9,
            is_malicious: true,
            protocol: Some("HTTP".to_string()),
            port: None,
            pattern: Some(r"(?i)(etc\/passwd|etc\/shadow|\.htaccess|web\.config)".to_string()),
            keywords: vec![],
        },
        
        // Port Scan rules
        DetectionRule {
            id: "PORT_SCAN_SYN".to_string(),
            name: "SYN Port Scan".to_string(),
            description: "Detected SYN scanning activity".to_string(),
            severity: 6,
            is_malicious: true,
            protocol: Some("TCP".to_string()),
            port: None,
            pattern: None,
            keywords: vec!["SYN".to_string()],
        },
        
        // Brute Force rules
        DetectionRule {
            id: "BRUTE_FORCE_SSH".to_string(),
            name: "SSH Brute Force".to_string(),
            description: "Multiple failed SSH login attempts".to_string(),
            severity: 7,
            is_malicious: true,
            protocol: Some("SSH".to_string()),
            port: Some(22),
            pattern: Some(r"(?i)(failed|denied|invalid\s+user)".to_string()),
            keywords: vec!["failed".to_string()],
        },
        
        // XSS rules
        DetectionRule {
            id: "XSS_SCRIPT_TAG".to_string(),
            name: "XSS - Script Tag".to_string(),
            description: "Detected script tag injection attempt".to_string(),
            severity: 7,
            is_malicious: true,
            protocol: Some("HTTP".to_string()),
            port: None,
            pattern: Some(r"(?i)<script[^>]*>.*<\/script>".to_string()),
            keywords: vec!["<script".to_string()],
        },
        
        // Normal traffic rules (for testing false positives)
        DetectionRule {
            id: "NORMAL_HTTP".to_string(),
            name: "Normal HTTP Traffic".to_string(),
            description: "Regular HTTP request".to_string(),
            severity: 1,
            is_malicious: false,
            protocol: Some("HTTP".to_string()),
            port: Some(80),
            pattern: Some(r"^GET\s+\/[a-zA-Z0-9\/_\-\.]+\s+HTTP".to_string()),
            keywords: vec![],
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_rules_load() {
        let rules = get_default_rules();
        assert!(!rules.is_empty());
        
        // Check that we have both malicious and benign rules
        let malicious_count = rules.iter().filter(|r| r.is_malicious).count();
        let benign_count = rules.iter().filter(|r| !r.is_malicious).count();
        
        assert!(malicious_count > 0);
        assert!(benign_count > 0);
    }
    
    #[test]
    fn test_rule_severity() {
        let rules = get_default_rules();
        
        for rule in &rules {
            assert!(rule.severity >= 1 && rule.severity <= 10);
            
            // Malicious rules should have higher severity
            if rule.is_malicious {
                assert!(rule.severity >= 6);
            }
        }
    }
}