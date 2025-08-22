// SPDX-License-Identifier: MIT
package scheduler

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/qubic/wargame-relay/blockchain"
	"github.com/sirupsen/logrus"
)

var log = logrus.New()

// Job represents a scheduled job
type Job struct {
	ID            uint32
	Spec          blockchain.JobSpec
	Status        string
	AssignedTo    string
	CreatedAt     time.Time
	StartedAt     *time.Time
	CompletedAt   *time.Time
	Result        *blockchain.ResultDigest
	RetryCount    int
}

// Scheduler manages job scheduling and execution
type Scheduler struct {
	client       *blockchain.Client
	mu           sync.RWMutex
	jobs         map[uint32]*Job
	pendingQueue chan uint32
	stopCh       chan struct{}
}

// New creates a new scheduler
func New(client *blockchain.Client) *Scheduler {
	return &Scheduler{
		client:       client,
		jobs:         make(map[uint32]*Job),
		pendingQueue: make(chan uint32, 1000),
		stopCh:       make(chan struct{}),
	}
}

// Run starts the scheduler
func (s *Scheduler) Run(ctx context.Context) {
	log.Info("Scheduler started")
	
	// Start job fetcher
	go s.fetchJobs(ctx)
	
	// Start job distributor
	go s.distributeJobs(ctx)
	
	// Start result collector
	go s.collectResults(ctx)
	
	// Wait for context cancellation
	<-ctx.Done()
	close(s.stopCh)
	log.Info("Scheduler stopped")
}

// fetchJobs periodically fetches new jobs from the blockchain
func (s *Scheduler) fetchJobs(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.fetchNewJobs(ctx)
		}
	}
}

func (s *Scheduler) fetchNewJobs(ctx context.Context) {
	// Get current round
	currentRound := s.client.GetCurrentRound()
	
	// Fetch pending jobs for current round
	jobs, err := s.client.ListJobs(ctx, &currentRound, "PENDING")
	if err != nil {
		log.Errorf("Failed to fetch jobs: %v", err)
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	for _, jobRecord := range jobs {
		// Skip if already tracked
		if _, exists := s.jobs[jobRecord.JobID]; exists {
			continue
		}

		// Create internal job representation
		job := &Job{
			ID:        jobRecord.JobID,
			Spec:      jobRecord.Spec,
			Status:    "PENDING",
			CreatedAt: time.Now(),
		}

		s.jobs[jobRecord.JobID] = job
		
		// Add to pending queue
		select {
		case s.pendingQueue <- jobRecord.JobID:
			log.Infof("Added job %d to pending queue", jobRecord.JobID)
		default:
			log.Warnf("Pending queue full, job %d dropped", jobRecord.JobID)
		}
	}
}

// distributeJobs assigns pending jobs to available workers
func (s *Scheduler) distributeJobs(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case jobID := <-s.pendingQueue:
			s.assignJob(ctx, jobID)
		}
	}
}

func (s *Scheduler) assignJob(ctx context.Context, jobID uint32) {
	s.mu.Lock()
	job, exists := s.jobs[jobID]
	if !exists {
		s.mu.Unlock()
		return
	}
	
	// Mark as assigned
	job.Status = "ASSIGNED"
	now := time.Now()
	job.StartedAt = &now
	s.mu.Unlock()

	// TODO: Actually assign to a worker via gRPC
	// For PoC, simulate job execution
	go s.simulateJobExecution(ctx, jobID)
}

func (s *Scheduler) simulateJobExecution(ctx context.Context, jobID uint32) {
	// Simulate job execution time
	executionTime := time.Duration(2+jobID%3) * time.Second
	select {
	case <-ctx.Done():
		return
	case <-time.After(executionTime):
	}

	s.mu.Lock()
	job, exists := s.jobs[jobID]
	if !exists {
		s.mu.Unlock()
		return
	}

	// Mark as completed
	job.Status = "COMPLETED"
	now := time.Now()
	job.CompletedAt = &now
	
	// Generate mock result
	result := blockchain.ResultDigest{
		Hash: fmt.Sprintf("%x", time.Now().UnixNano()),
		URI:  fmt.Sprintf("minio://artifacts/job-%d/metrics.json", jobID),
	}
	job.Result = &result
	s.mu.Unlock()

	// Report result to blockchain
	if err := s.client.ReportResult(ctx, jobID, result); err != nil {
		log.Errorf("Failed to report result for job %d: %v", jobID, err)
	} else {
		log.Infof("Reported result for job %d", jobID)
	}
}

// collectResults collects results from completed jobs
func (s *Scheduler) collectResults(ctx context.Context) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.checkCompletedJobs(ctx)
		}
	}
}

func (s *Scheduler) checkCompletedJobs(ctx context.Context) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	completedCount := 0
	for _, job := range s.jobs {
		if job.Status == "COMPLETED" {
			completedCount++
		}
	}

	if completedCount > 0 {
		log.Infof("Completed jobs: %d/%d", completedCount, len(s.jobs))
	}
}

// ListJobs returns jobs matching the criteria
func (s *Scheduler) ListJobs(roundID, status string) ([]*Job, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var result []*Job
	for _, job := range s.jobs {
		// Filter by round if specified
		if roundID != "" && fmt.Sprintf("%d", job.Spec.RoundID) != roundID {
			continue
		}
		
		// Filter by status if specified
		if status != "" && job.Status != status {
			continue
		}
		
		result = append(result, job)
	}

	return result, nil
}

// GetJob returns a specific job
func (s *Scheduler) GetJob(jobID uint32) (*Job, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	job, exists := s.jobs[jobID]
	if !exists {
		return nil, fmt.Errorf("job not found")
	}

	return job, nil
}

// GetRoundSummary returns round statistics
func (s *Scheduler) GetRoundSummary(roundID uint32) (*blockchain.RoundSummary, error) {
	ctx := context.Background()
	return s.client.GetRoundSummary(ctx, roundID)
}