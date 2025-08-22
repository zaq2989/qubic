// SPDX-License-Identifier: MIT
package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
	"github.com/qubic/wargame-relay/src/scheduler"
	"github.com/qubic/wargame-relay/src/worker"
)

type Handler struct {
	scheduler *scheduler.Scheduler
	pool      *worker.Pool
}

func NewHandler(sched *scheduler.Scheduler, pool *worker.Pool) *Handler {
	return &Handler{
		scheduler: sched,
		pool:      pool,
	}
}

func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"status": "healthy",
		"workers": map[string]interface{}{
			"total":     h.pool.TotalWorkers(),
			"available": h.pool.AvailableWorkers(),
		},
	}
	writeJSON(w, http.StatusOK, response)
}

func (h *Handler) ListJobs(w http.ResponseWriter, r *http.Request) {
	roundID := r.URL.Query().Get("round")
	status := r.URL.Query().Get("status")

	jobs, err := h.scheduler.ListJobs(roundID, status)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, jobs)
}

func (h *Handler) GetJob(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	jobID, err := strconv.ParseUint(vars["id"], 10, 32)
	if err != nil {
		writeError(w, http.StatusBadRequest, "Invalid job ID")
		return
	}

	job, err := h.scheduler.GetJob(uint32(jobID))
	if err != nil {
		writeError(w, http.StatusNotFound, "Job not found")
		return
	}

	writeJSON(w, http.StatusOK, job)
}

func (h *Handler) ListWorkers(w http.ResponseWriter, r *http.Request) {
	workers := h.pool.ListWorkers()
	writeJSON(w, http.StatusOK, workers)
}

func (h *Handler) GetRoundSummary(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	roundID, err := strconv.ParseUint(vars["id"], 10, 32)
	if err != nil {
		writeError(w, http.StatusBadRequest, "Invalid round ID")
		return
	}

	summary, err := h.scheduler.GetRoundSummary(uint32(roundID))
	if err != nil {
		writeError(w, http.StatusNotFound, "Round not found")
		return
	}

	writeJSON(w, http.StatusOK, summary)
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
