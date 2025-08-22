// SPDX-License-Identifier: MIT
package worker

import (
	"fmt"
	"sync"
	"time"
)

// WorkerInfo represents information about a connected worker
type WorkerInfo struct {
	ID           string
	Capabilities WorkerCapabilities
	Status       WorkerStatus
	SessionToken string
	LastSeen     time.Time
	RegisteredAt time.Time
}

// Pool manages connected workers
type Pool struct {
	mu      sync.RWMutex
	workers map[string]*WorkerInfo
	maxSize int
}

// NewPool creates a new worker pool
func NewPool(maxSize int) *Pool {
	pool := &Pool{
		workers: make(map[string]*WorkerInfo),
		maxSize: maxSize,
	}
	
	// Start cleanup goroutine
	go pool.cleanupStaleWorkers()
	
	return pool
}

// Register adds a new worker to the pool
func (p *Pool) Register(workerID string, capabilities *WorkerCapabilities) (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	// Check if pool is full
	if len(p.workers) >= p.maxSize {
		return "", fmt.Errorf("worker pool is full")
	}

	// Generate session token
	sessionToken := fmt.Sprintf("session-%s-%d", workerID, time.Now().UnixNano())

	// Create worker info
	info := &WorkerInfo{
		ID:           workerID,
		Capabilities: *capabilities,
		SessionToken: sessionToken,
		LastSeen:     time.Now(),
		RegisteredAt: time.Now(),
	}

	p.workers[workerID] = info
	
	return sessionToken, nil
}

// UpdateHeartbeat updates worker heartbeat
func (p *Pool) UpdateHeartbeat(workerID, sessionToken string, status *WorkerStatus) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	worker, exists := p.workers[workerID]
	if !exists {
		return fmt.Errorf("worker not found")
	}

	if worker.SessionToken != sessionToken {
		return fmt.Errorf("invalid session token")
	}

	worker.Status = *status
	worker.LastSeen = time.Now()

	return nil
}

// GetAvailableWorker returns an available worker for a job type
func (p *Pool) GetAvailableWorker(jobType string) *WorkerInfo {
	p.mu.RLock()
	defer p.mu.RUnlock()

	for _, worker := range p.workers {
		// Check if worker supports job type
		supports := false
		for _, t := range worker.Capabilities.JobTypes {
			if t == jobType {
				supports = true
				break
			}
		}

		if !supports {
			continue
		}

		// Check if worker has capacity
		if worker.Status.ActiveJobs < worker.Capabilities.MaxConcurrentJobs {
			// Check if worker is alive
			if time.Since(worker.LastSeen) < 30*time.Second {
				return worker
			}
		}
	}

	return nil
}

// Remove removes a worker from the pool
func (p *Pool) Remove(workerID string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	delete(p.workers, workerID)
}

// ListWorkers returns all workers in the pool
func (p *Pool) ListWorkers() []*WorkerInfo {
	p.mu.RLock()
	defer p.mu.RUnlock()

	result := make([]*WorkerInfo, 0, len(p.workers))
	for _, worker := range p.workers {
		result = append(result, worker)
	}

	return result
}

// TotalWorkers returns the total number of workers
func (p *Pool) TotalWorkers() int {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return len(p.workers)
}

// AvailableWorkers returns the number of available workers
func (p *Pool) AvailableWorkers() int {
	p.mu.RLock()
	defer p.mu.RUnlock()

	count := 0
	for _, worker := range p.workers {
		if time.Since(worker.LastSeen) < 30*time.Second &&
			worker.Status.ActiveJobs < worker.Capabilities.MaxConcurrentJobs {
			count++
		}
	}

	return count
}

// cleanupStaleWorkers removes workers that haven't sent heartbeat
func (p *Pool) cleanupStaleWorkers() {
	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		p.mu.Lock()
		
		staleWorkers := []string{}
		for id, worker := range p.workers {
			if time.Since(worker.LastSeen) > 2*time.Minute {
				staleWorkers = append(staleWorkers, id)
			}
		}

		for _, id := range staleWorkers {
			delete(p.workers, id)
		}

		p.mu.Unlock()

		if len(staleWorkers) > 0 {
			log.Infof("Removed %d stale workers", len(staleWorkers))
		}
	}
}