// SPDX-License-Identifier: MIT
package blockchain

import (
	"context"
	"crypto/ed25519"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

// JobSpec represents a job specification
type JobSpec struct {
	RoundID       uint32 `json:"round_id"`
	JobType       string `json:"job_type"`
	Seed          string `json:"seed"`
	TargetProfile string `json:"target_profile"`
	TimeBudgetMS  uint32 `json:"time_budget_ms"`
}

// JobRecord represents a complete job record
type JobRecord struct {
	JobID       uint32      `json:"job_id"`
	Spec        JobSpec     `json:"spec"`
	Status      string      `json:"status"`
	SubmittedAt uint64      `json:"submitted_at"`
	CompletedAt uint64      `json:"completed_at"`
	Result      ResultDigest `json:"result,omitempty"`
	WorkerID    string      `json:"worker_id"`
}

// ResultDigest represents the result of a job
type ResultDigest struct {
	Hash      string `json:"hash"`
	URI       string `json:"uri"`
	Signature string `json:"signature"`
}

// RoundSummary represents round statistics
type RoundSummary struct {
	RoundID            uint32 `json:"round_id"`
	TotalJobs          uint32 `json:"total_jobs"`
	CompletedJobs      uint32 `json:"completed_jobs"`
	FailedJobs         uint32 `json:"failed_jobs"`
	AttackSuccessCount uint32 `json:"attack_success_count"`
	DefenseSuccessCount uint32 `json:"defense_success_count"`
	StartedAt          uint64 `json:"started_at"`
	EndedAt            uint64 `json:"ended_at"`
}

// Client represents a blockchain client
type Client struct {
	endpoint   string
	privateKey ed25519.PrivateKey
	publicKey  ed25519.PublicKey
	
	// Mock storage for PoC
	mu         sync.RWMutex
	jobs       map[uint32]*JobRecord
	rounds     map[uint32]*RoundSummary
	nextJobID  uint32
	currentRound uint32
}

// NewClient creates a new blockchain client
func NewClient(endpoint string) (*Client, error) {
	// Generate keypair for PoC
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		return nil, err
	}

	client := &Client{
		endpoint:   endpoint,
		privateKey: priv,
		publicKey:  pub,
		jobs:       make(map[uint32]*JobRecord),
		rounds:     make(map[uint32]*RoundSummary),
		nextJobID:  1,
		currentRound: 1,
	}

	// Initialize first round
	client.rounds[1] = &RoundSummary{
		RoundID:   1,
		StartedAt: uint64(time.Now().Unix()),
	}

	return client, nil
}

// SubmitJob submits a new job to the blockchain
func (c *Client) SubmitJob(ctx context.Context, spec JobSpec) (uint32, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	jobID := c.nextJobID
	c.nextJobID++

	job := &JobRecord{
		JobID:       jobID,
		Spec:        spec,
		Status:      "PENDING",
		SubmittedAt: uint64(time.Now().Unix()),
		WorkerID:    hex.EncodeToString(c.publicKey),
	}

	c.jobs[jobID] = job
	
	// Update round stats
	if round, ok := c.rounds[spec.RoundID]; ok {
		round.TotalJobs++
	}

	return jobID, nil
}

// ReportResult reports job completion
func (c *Client) ReportResult(ctx context.Context, jobID uint32, result ResultDigest) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	job, ok := c.jobs[jobID]
	if !ok {
		return fmt.Errorf("job %d not found", jobID)
	}

	if job.Status != "PENDING" && job.Status != "IN_PROGRESS" {
		return fmt.Errorf("job %d already completed", jobID)
	}

	// Sign the result
	message := []byte(result.Hash + result.URI)
	signature := ed25519.Sign(c.privateKey, message)
	result.Signature = hex.EncodeToString(signature)

	job.Status = "COMPLETED"
	job.CompletedAt = uint64(time.Now().Unix())
	job.Result = result

	// Update round stats
	if round, ok := c.rounds[job.Spec.RoundID]; ok {
		round.CompletedJobs++
		
		// Simplified success detection for PoC
		hashBytes, _ := hex.DecodeString(result.Hash)
		if len(hashBytes) > 0 && (hashBytes[0]&0x01) == 1 {
			if job.Spec.JobType == "ATTACK" {
				round.AttackSuccessCount++
			} else if job.Spec.JobType == "DEFENSE" {
				round.DefenseSuccessCount++
			}
		}
	}

	return nil
}

// GetJob retrieves a job by ID
func (c *Client) GetJob(ctx context.Context, jobID uint32) (*JobRecord, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	job, ok := c.jobs[jobID]
	if !ok {
		return nil, fmt.Errorf("job %d not found", jobID)
	}

	return job, nil
}

// ListJobs lists jobs with optional filtering
func (c *Client) ListJobs(ctx context.Context, roundID *uint32, status string) ([]*JobRecord, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	var results []*JobRecord
	
	for _, job := range c.jobs {
		// Filter by round if specified
		if roundID != nil && job.Spec.RoundID != *roundID {
			continue
		}
		
		// Filter by status if specified
		if status != "" && job.Status != status {
			continue
		}
		
		results = append(results, job)
	}

	return results, nil
}

// GetRoundSummary retrieves round statistics
func (c *Client) GetRoundSummary(ctx context.Context, roundID uint32) (*RoundSummary, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	round, ok := c.rounds[roundID]
	if !ok {
		return nil, fmt.Errorf("round %d not found", roundID)
	}

	return round, nil
}

// FinalizeRound finalizes a round
func (c *Client) FinalizeRound(ctx context.Context, roundID uint32) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	round, ok := c.rounds[roundID]
	if !ok {
		return fmt.Errorf("round %d not found", roundID)
	}

	// Mark pending jobs as failed
	for _, job := range c.jobs {
		if job.Spec.RoundID == roundID && job.Status == "PENDING" {
			job.Status = "FAILED"
			round.FailedJobs++
		}
	}

	round.EndedAt = uint64(time.Now().Unix())
	
	return nil
}

// StartNewRound starts a new round
func (c *Client) StartNewRound(ctx context.Context) (uint32, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Finalize current round
	if currentRound, ok := c.rounds[c.currentRound]; ok && currentRound.EndedAt == 0 {
		currentRound.EndedAt = uint64(time.Now().Unix())
	}

	c.currentRound++
	c.rounds[c.currentRound] = &RoundSummary{
		RoundID:   c.currentRound,
		StartedAt: uint64(time.Now().Unix()),
	}

	return c.currentRound, nil
}

// GetCurrentRound returns the current round ID
func (c *Client) GetCurrentRound() uint32 {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.currentRound
}