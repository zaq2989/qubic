// SPDX-License-Identifier: MIT
mod defender;
mod detector;
mod rules;
mod metrics;

use anyhow::Result;
use clap::Parser;
use std::time::Duration;
use tokio::time::sleep;
use tonic::transport::Channel;
use tracing::{error, info, warn};
use tracing_subscriber;

pub mod worker {
    tonic::include_proto!("worker");
}

use worker::worker_service_client::WorkerServiceClient;
use worker::{
    GetJobRequest, HeartbeatRequest, RegisterRequest, ReportResultRequest,
    WorkerCapabilities, WorkerStatus,
};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(short, long, default_value = "http://localhost:9090")]
    relay_endpoint: String,

    #[arg(short, long, default_value = "defender-1")]
    worker_id: String,

    #[arg(short, long, default_value_t = 2)]
    max_concurrent_jobs: u32,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    let args = Args::parse();
    info!("Starting defense worker {}", args.worker_id);

    // Load detection rules
    rules::load_default_rules()?;

    // Connect to relay
    let mut client = connect_to_relay(&args.relay_endpoint).await?;

    // Register with relay
    let session_token = register_worker(&mut client, &args).await?;

    // Main worker loop
    let mut completed_jobs = 0u32;
    let mut active_jobs = 0u32;

    loop {
        // Send heartbeat
        send_heartbeat(&mut client, &args.worker_id, &session_token, active_jobs, completed_jobs).await?;

        // Check for new jobs
        if active_jobs < args.max_concurrent_jobs {
            match get_job(&mut client, &args.worker_id, &session_token).await {
                Ok(Some(job)) => {
                    info!("Received job {}", job.job_id);
                    active_jobs += 1;
                    
                    // Spawn task to handle job
                    let client_clone = client.clone();
                    let worker_id = args.worker_id.clone();
                    let session_token_clone = session_token.clone();
                    
                    tokio::spawn(async move {
                        if let Err(e) = execute_job(client_clone, worker_id, session_token_clone, job).await {
                            error!("Failed to execute job: {}", e);
                        }
                    });
                }
                Ok(None) => {
                    // No jobs available
                }
                Err(e) => {
                    warn!("Failed to get job: {}", e);
                }
            }
        }

        // Sleep before next iteration
        sleep(Duration::from_secs(5)).await;
    }
}

async fn connect_to_relay(endpoint: &str) -> Result<WorkerServiceClient<Channel>> {
    info!("Connecting to relay at {}", endpoint);
    let client = WorkerServiceClient::connect(endpoint.to_string()).await?;
    Ok(client)
}

async fn register_worker(
    client: &mut WorkerServiceClient<Channel>,
    args: &Args,
) -> Result<String> {
    let request = RegisterRequest {
        worker_id: args.worker_id.clone(),
        capabilities: Some(WorkerCapabilities {
            job_types: vec!["DEFENSE".to_string()],
            max_concurrent_jobs: args.max_concurrent_jobs,
            cpu_cores: num_cpus::get() as u32,
            memory_mb: 1024, // 1GB
        }),
    };

    let response = client.register(request).await?;
    let inner = response.into_inner();
    
    if !inner.success {
        return Err(anyhow::anyhow!("Registration failed: {}", inner.message));
    }

    info!("Successfully registered with relay");
    Ok(inner.session_token)
}

async fn send_heartbeat(
    client: &mut WorkerServiceClient<Channel>,
    worker_id: &str,
    session_token: &str,
    active_jobs: u32,
    completed_jobs: u32,
) -> Result<()> {
    let request = HeartbeatRequest {
        worker_id: worker_id.to_string(),
        session_token: session_token.to_string(),
        status: Some(WorkerStatus {
            active_jobs,
            completed_jobs,
            cpu_usage: 0.5, // Placeholder
            memory_usage: 0.3, // Placeholder
        }),
    };

    client.heartbeat(request).await?;
    Ok(())
}

async fn get_job(
    client: &mut WorkerServiceClient<Channel>,
    worker_id: &str,
    session_token: &str,
) -> Result<Option<worker::Job>> {
    let request = GetJobRequest {
        worker_id: worker_id.to_string(),
        session_token: session_token.to_string(),
        preferred_types: vec!["DEFENSE".to_string()],
    };

    let response = client.get_job(request).await?;
    let inner = response.into_inner();
    
    if inner.has_job {
        Ok(inner.job)
    } else {
        Ok(None)
    }
}

async fn execute_job(
    mut client: WorkerServiceClient<Channel>,
    worker_id: String,
    session_token: String,
    job: worker::Job,
) -> Result<()> {
    info!("Executing defense job {}", job.job_id);
    
    // Execute the defense analysis
    let start_time = std::time::Instant::now();
    let result = defender::analyze_traffic(&job).await?;
    let execution_time = start_time.elapsed();
    
    // Report result
    let request = ReportResultRequest {
        worker_id,
        session_token,
        job_id: job.job_id,
        result: Some(worker::ResultData {
            hash: result.hash.into_bytes(),
            uri: result.uri,
            signature: result.signature.into_bytes(),
            success: result.detected,
            execution_time_ms: execution_time.as_millis() as u32,
        }),
    };

    let response = client.report_result(request).await?;
    let inner = response.into_inner();
    
    if !inner.accepted {
        return Err(anyhow::anyhow!("Result not accepted: {}", inner.message));
    }

    info!("Job {} completed successfully", job.job_id);
    Ok(())
}