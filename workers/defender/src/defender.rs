// SPDX-License-Identifier: MIT
use crate::detector::{DetectionEngine, TrafficEvent};
use crate::metrics::DefenseMetrics;
use crate::worker;
use anyhow::Result;
use ed25519_dalek::{Signer, SigningKey};
use rand::SeedableRng;
use rand_chacha::ChaCha8Rng;
use sha2::{Digest, Sha256};
use std::time::Instant;
use tracing::{debug, info};

pub struct DefenseResult {
    pub hash: String,
    pub uri: String,
    pub signature: String,
    pub detected: bool,
}

pub async fn analyze_traffic(job: &worker::Job) -> Result<DefenseResult> {
    info!("Starting defense analysis for job {} with seed {:?}", job.job_id, hex::encode(&job.seed));
    
    // Initialize deterministic RNG from seed
    let mut rng = create_rng(&job.seed);
    
    // Initialize metrics
    let mut metrics = DefenseMetrics {
        job_id: job.job_id,
        round_id: job.round_id,
        detected: false,
        true_positive_rate: 0.0,
        false_positive_rate: 0.0,
        alerts_generated: 0,
        events_analyzed: 0,
        detection_rules_matched: vec![],
        timestamps: vec![],
    };
    
    let start_time = Instant::now();
    
    // Initialize detection engine with seed-based configuration
    let mut engine = DetectionEngine::new(&mut rng);
    
    // Generate simulated traffic events based on target profile
    let events = generate_traffic_events(&mut rng, &job.target_profile, job.time_budget_ms);
    metrics.events_analyzed = events.len() as u32;
    
    // Analyze each event
    for event in &events {
        if let Some(alert) = engine.analyze_event(event) {
            metrics.alerts_generated += 1;
            metrics.detection_rules_matched.push(alert.rule_id.clone());
            
            if alert.is_malicious {
                metrics.detected = true;
                metrics.timestamps.push((
                    format!("malicious_detected_{}", alert.rule_id),
                    start_time.elapsed().as_millis() as u64
                ));
                debug!("Detected malicious activity: {}", alert.description);
            }
        }
    }
    
    // Calculate detection rates (simplified for PoC)
    let (tpr, fpr) = calculate_detection_rates(&mut rng, metrics.detected);
    metrics.true_positive_rate = tpr;
    metrics.false_positive_rate = fpr;
    
    // Log final detection status
    info!("Defense analysis complete: detected={}, TPR={:.2}, FPR={:.2}", 
          metrics.detected, tpr, fpr);
    
    // Generate result
    let result_json = serde_json::to_string(&metrics)?;
    let hash = calculate_hash(&result_json);
    
    // Store result (in real implementation, would upload to MinIO)
    let uri = format!("minio://artifacts/job-{}/metrics.json", job.job_id);
    
    // Sign the result
    let signing_key = generate_signing_key(&job.seed);
    let signature = sign_result(&signing_key, &hash, &uri);
    
    Ok(DefenseResult {
        hash,
        uri,
        signature,
        detected: metrics.detected,
    })
}

fn create_rng(seed: &[u8]) -> ChaCha8Rng {
    let mut hasher = Sha256::new();
    hasher.update(seed);
    let hash = hasher.finalize();
    
    let mut seed_bytes = [0u8; 32];
    seed_bytes.copy_from_slice(&hash);
    
    ChaCha8Rng::from_seed(seed_bytes)
}

fn generate_traffic_events(
    rng: &mut ChaCha8Rng,
    target_profile: &[u8],
    time_budget_ms: u32,
) -> Vec<TrafficEvent> {
    use rand::Rng;
    
    let mut events = vec![];
    let num_events = (time_budget_ms / 10).min(500) as usize; // ~100 events per second max
    
    // Determine attack probability from target profile
    let attack_probability = if !target_profile.is_empty() {
        (target_profile[0] as f32) / 255.0 * 0.3 + 0.1 // 10-40% attack traffic
    } else {
        0.2
    };
    
    for i in 0..num_events {
        let timestamp = (i as u64) * 10; // 10ms intervals
        let is_attack = rng.gen::<f32>() < attack_probability;
        
        let event = if is_attack {
            generate_attack_event(rng, timestamp)
        } else {
            generate_normal_event(rng, timestamp)
        };
        
        events.push(event);
    }
    
    events
}

fn generate_attack_event(rng: &mut ChaCha8Rng, timestamp: u64) -> TrafficEvent {
    use rand::Rng;
    
    let attack_types = vec![
        ("port_scan", "10.0.0.1", vec![22, 80, 443, 3306], "SYN scan detected"),
        ("sql_injection", "10.0.0.2", vec![3306], "SELECT * FROM users WHERE id=1 OR 1=1"),
        ("path_traversal", "10.0.0.3", vec![80], "GET /../../../etc/passwd HTTP/1.1"),
        ("command_injection", "10.0.0.4", vec![80], "ping -c 1 127.0.0.1; cat /etc/passwd"),
        ("brute_force", "10.0.0.5", vec![22], "Multiple failed SSH login attempts"),
    ];
    
    let attack_idx = rng.gen_range(0..attack_types.len());
    let (event_type, src_ip, ports, payload) = &attack_types[attack_idx];
    
    TrafficEvent {
        timestamp,
        src_ip: src_ip.to_string(),
        dst_ip: "192.168.1.100".to_string(),
        src_port: rng.gen_range(1024..65535),
        dst_port: ports[rng.gen_range(0..ports.len())],
        protocol: if *event_type == "port_scan" { "TCP" } else { "HTTP" }.to_string(),
        payload: payload.to_string(),
        flags: if *event_type == "port_scan" { vec!["SYN".to_string()] } else { vec![] },
    }
}

fn generate_normal_event(rng: &mut ChaCha8Rng, timestamp: u64) -> TrafficEvent {
    use rand::Rng;
    
    let normal_traffic = vec![
        ("HTTP", 80, "GET /index.html HTTP/1.1"),
        ("HTTPS", 443, "TLS Client Hello"),
        ("DNS", 53, "Query: example.com"),
        ("SSH", 22, "SSH-2.0-OpenSSH_8.2"),
    ];
    
    let traffic_idx = rng.gen_range(0..normal_traffic.len());
    let (protocol, port, payload) = &normal_traffic[traffic_idx];
    
    TrafficEvent {
        timestamp,
        src_ip: format!("10.0.1.{}", rng.gen_range(1..255)),
        dst_ip: "192.168.1.100".to_string(),
        src_port: rng.gen_range(1024..65535),
        dst_port: *port,
        protocol: protocol.to_string(),
        payload: payload.to_string(),
        flags: vec![],
    }
}

fn calculate_detection_rates(rng: &mut ChaCha8Rng, detected: bool) -> (f64, f64) {
    use rand::Rng;
    
    // Simplified detection rate calculation for PoC
    // In real implementation, would compare against ground truth
    if detected {
        // If we detected something, assume decent TPR
        let tpr = 0.85 + rng.gen::<f64>() * 0.1; // 85-95%
        let fpr = 0.02 + rng.gen::<f64>() * 0.03; // 2-5%
        (tpr, fpr)
    } else {
        // If we didn't detect, might have missed attacks
        let tpr = 0.3 + rng.gen::<f64>() * 0.3; // 30-60%
        let fpr = 0.01 + rng.gen::<f64>() * 0.02; // 1-3%
        (tpr, fpr)
    }
}

fn calculate_hash(data: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(data.as_bytes());
    hex::encode(hasher.finalize())
}

fn generate_signing_key(seed: &[u8]) -> SigningKey {
    let mut key_bytes = [0u8; 32];
    let mut hasher = Sha256::new();
    hasher.update(b"defender_signing_key");
    hasher.update(seed);
    let hash = hasher.finalize();
    key_bytes.copy_from_slice(&hash);
    
    SigningKey::from_bytes(&key_bytes)
}

fn sign_result(signing_key: &SigningKey, hash: &str, uri: &str) -> String {
    let message = format!("{}{}", hash, uri);
    let signature = signing_key.sign(message.as_bytes());
    hex::encode(signature.to_bytes())
}