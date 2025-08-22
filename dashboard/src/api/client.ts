// SPDX-License-Identifier: MIT
import axios from 'axios';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '/api/relay';

export interface Job {
  job_id: number;
  spec: {
    round_id: number;
    job_type: 'ATTACK' | 'DEFENSE';
    seed: string;
    target_profile: string;
    time_budget_ms: number;
  };
  status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED';
  submitted_at: number;
  completed_at?: number;
  result?: {
    hash: string;
    uri: string;
    signature: string;
  };
  worker_id: string;
}

export interface RoundSummary {
  round_id: number;
  total_jobs: number;
  completed_jobs: number;
  failed_jobs: number;
  attack_success_count: number;
  defense_success_count: number;
  started_at: number;
  ended_at?: number;
}

export interface Worker {
  id: string;
  capabilities: {
    job_types: string[];
    max_concurrent_jobs: number;
    cpu_cores: number;
    memory_mb: number;
  };
  status: {
    active_jobs: number;
    completed_jobs: number;
    cpu_usage: number;
    memory_usage: number;
  };
  last_seen: string;
  registered_at: string;
}

export interface Metrics {
  job_id: number;
  round_id: number;
  success?: boolean;
  detected?: boolean;
  exploit_time_ms?: number;
  true_positive_rate?: number;
  false_positive_rate?: number;
  attempts?: number;
  alerts_generated?: number;
}

class ApiClient {
  private client = axios.create({
    baseURL: API_BASE_URL,
    timeout: 10000,
  });

  async getHealth(): Promise<{ status: string; workers: { total: number; available: number } }> {
    const response = await this.client.get('/health');
    return response.data;
  }

  async getRoundSummary(roundId: number): Promise<RoundSummary> {
    const response = await this.client.get(`/rounds/${roundId}/summary`);
    return response.data;
  }

  async listJobs(round?: string, status?: string): Promise<Job[]> {
    const params = new URLSearchParams();
    if (round) params.append('round', round);
    if (status) params.append('status', status);
    
    const response = await this.client.get(`/jobs?${params.toString()}`);
    return response.data;
  }

  async getJob(jobId: number): Promise<Job> {
    const response = await this.client.get(`/jobs/${jobId}`);
    return response.data;
  }

  async getJobMetrics(jobId: number): Promise<Metrics> {
    const response = await this.client.get(`/job/${jobId}/metrics`);
    return response.data;
  }

  async listWorkers(): Promise<Worker[]> {
    const response = await this.client.get('/workers');
    return response.data;
  }
}

export const apiClient = new ApiClient();