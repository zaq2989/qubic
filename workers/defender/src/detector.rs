// SPDX-License-Identifier: MIT
use crate::rules::{DetectionRule, RuleEngine};
use rand::Rng;
use rand_chacha::ChaCha8Rng;
use regex::Regex;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct TrafficEvent {
    pub timestamp: u64,
    pub src_ip: String,
    pub dst_ip: String,
    pub src_port: u16,
    pub dst_port: u16,
    pub protocol: String,
    pub payload: String,
    pub flags: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct Alert {
    pub rule_id: String,
    pub description: String,
    pub severity: u8,
    pub is_malicious: bool,
    pub event: TrafficEvent,
}

pub struct DetectionEngine {
    rule_engine: RuleEngine,
    state: DetectionState,
    sensitivity: f32,
}

#[derive(Default)]
struct DetectionState {
    connection_counts: HashMap<String, u32>,
    failed_logins: HashMap<String, u32>,
    scan_attempts: HashMap<String, Vec<u16>>,
}

impl DetectionEngine {
    pub fn new(rng: &mut ChaCha8Rng) -> Self {
        // Deterministic sensitivity based on RNG
        let sensitivity = 0.7 + rng.gen::<f32>() * 0.2; // 0.7-0.9
        
        Self {
            rule_engine: RuleEngine::new(),
            state: DetectionState::default(),
            sensitivity,
        }
    }
    
    pub fn analyze_event(&mut self, event: &TrafficEvent) -> Option<Alert> {
        // Update state
        self.update_state(event);
        
        // Check against detection rules
        if let Some(rule) = self.rule_engine.match_event(event) {
            return Some(self.create_alert(rule, event));
        }
        
        // Check behavioral patterns
        if let Some(alert) = self.check_behavioral_patterns(event) {
            return Some(alert);
        }
        
        None
    }
    
    fn update_state(&mut self, event: &TrafficEvent) {
        let src_ip = &event.src_ip;
        
        // Track connection counts
        *self.state.connection_counts.entry(src_ip.clone()).or_insert(0) += 1;
        
        // Track port scans
        if event.flags.contains(&"SYN".to_string()) {
            self.state.scan_attempts
                .entry(src_ip.clone())
                .or_insert_with(Vec::new)
                .push(event.dst_port);
        }
        
        // Track failed logins
        if event.payload.contains("failed") || event.payload.contains("denied") {
            *self.state.failed_logins.entry(src_ip.clone()).or_insert(0) += 1;
        }
    }
    
    fn check_behavioral_patterns(&self, event: &TrafficEvent) -> Option<Alert> {
        let src_ip = &event.src_ip;
        
        // Port scan detection
        if let Some(ports) = self.state.scan_attempts.get(src_ip) {
            if ports.len() > (10.0 * self.sensitivity) as usize {
                return Some(Alert {
                    rule_id: "BEHAVIOR_PORTSCAN".to_string(),
                    description: format!("Port scan detected from {}", src_ip),
                    severity: 7,
                    is_malicious: true,
                    event: event.clone(),
                });
            }
        }
        
        // Brute force detection
        if let Some(&failed_count) = self.state.failed_logins.get(src_ip) {
            if failed_count > (5.0 * self.sensitivity) as u32 {
                return Some(Alert {
                    rule_id: "BEHAVIOR_BRUTEFORCE".to_string(),
                    description: format!("Brute force attack detected from {}", src_ip),
                    severity: 8,
                    is_malicious: true,
                    event: event.clone(),
                });
            }
        }
        
        // High connection rate detection
        if let Some(&conn_count) = self.state.connection_counts.get(src_ip) {
            if conn_count > (100.0 * self.sensitivity) as u32 {
                return Some(Alert {
                    rule_id: "BEHAVIOR_FLOOD".to_string(),
                    description: format!("Connection flood detected from {}", src_ip),
                    severity: 6,
                    is_malicious: true,
                    event: event.clone(),
                });
            }
        }
        
        None
    }
    
    fn create_alert(&self, rule: &DetectionRule, event: &TrafficEvent) -> Alert {
        Alert {
            rule_id: rule.id.clone(),
            description: rule.description.clone(),
            severity: rule.severity,
            is_malicious: rule.is_malicious,
            event: event.clone(),
        }
    }
}

impl RuleEngine {
    pub fn match_event(&self, event: &TrafficEvent) -> Option<&DetectionRule> {
        for rule in &self.rules {
            if self.matches_rule(rule, event) {
                return Some(rule);
            }
        }
        None
    }
    
    fn matches_rule(&self, rule: &DetectionRule, event: &TrafficEvent) -> bool {
        // Check protocol
        if let Some(ref protocol) = rule.protocol {
            if event.protocol != *protocol {
                return false;
            }
        }
        
        // Check port
        if let Some(port) = rule.port {
            if event.dst_port != port && event.src_port != port {
                return false;
            }
        }
        
        // Check pattern in payload
        if let Some(ref pattern) = rule.pattern {
            if let Ok(re) = Regex::new(pattern) {
                if !re.is_match(&event.payload) {
                    return false;
                }
            }
        }
        
        // Check keywords
        for keyword in &rule.keywords {
            if !event.payload.contains(keyword) {
                return false;
            }
        }
        
        true
    }
}