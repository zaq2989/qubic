// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"google.golang.org/grpc"

	"github.com/qubic/wargame-relay/api"
	"github.com/qubic/wargame-relay/blockchain"
	"github.com/qubic/wargame-relay/scheduler"
	"github.com/qubic/wargame-relay/worker"
)

var log = logrus.New()

func main() {
	// Initialize configuration
	initConfig()

	// Setup logging
	setupLogging()

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize blockchain client
	bcClient, err := blockchain.NewClient(viper.GetString("blockchain.endpoint"))
	if err != nil {
		log.Fatalf("Failed to create blockchain client: %v", err)
	}

	// Initialize scheduler
	sched := scheduler.New(bcClient)

	// Initialize worker pool
	pool := worker.NewPool(viper.GetInt("worker.pool_size"))

	// Start gRPC server for workers
	grpcServer := startGRPCServer(pool)

	// Start HTTP API server
	httpServer := startHTTPServer(sched, pool)

	// Start scheduler
	go sched.Run(ctx)

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Info("Shutting down relay service...")

	// Graceful shutdown
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	// Stop HTTP server
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Errorf("HTTP server shutdown error: %v", err)
	}

	// Stop gRPC server
	grpcServer.GracefulStop()

	// Cancel context to stop scheduler
	cancel()

	log.Info("Relay service stopped")
}

func initConfig() {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("/etc/wargame-relay/")

	// Set defaults
	viper.SetDefault("server.http_port", 8080)
	viper.SetDefault("server.grpc_port", 9090)
	viper.SetDefault("blockchain.endpoint", "localhost:10000")
	viper.SetDefault("worker.pool_size", 10)
	viper.SetDefault("log.level", "info")

	// Read environment variables
	viper.AutomaticEnv()

	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			log.Fatalf("Error reading config file: %v", err)
		}
		log.Warn("No config file found, using defaults and environment variables")
	}
}

func setupLogging() {
	// Set log level
	level, err := logrus.ParseLevel(viper.GetString("log.level"))
	if err != nil {
		level = logrus.InfoLevel
	}
	log.SetLevel(level)

	// Set formatter
	log.SetFormatter(&logrus.JSONFormatter{
		TimestampFormat: time.RFC3339,
	})
}

func startGRPCServer(pool *worker.Pool) *grpc.Server {
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", viper.GetInt("server.grpc_port")))
	if err != nil {
		log.Fatalf("Failed to listen on gRPC port: %v", err)
	}

	grpcServer := grpc.NewServer()
	workerService := worker.NewService(pool)
	worker.RegisterWorkerServiceServer(grpcServer, workerService)

	go func() {
		log.Infof("gRPC server listening on port %d", viper.GetInt("server.grpc_port"))
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("Failed to serve gRPC: %v", err)
		}
	}()

	return grpcServer
}

func startHTTPServer(sched *scheduler.Scheduler, pool *worker.Pool) *http.Server {
	router := mux.NewRouter()

	// Initialize API handlers
	apiHandler := api.NewHandler(sched, pool)

	// Register routes
	router.HandleFunc("/api/health", apiHandler.HealthCheck).Methods("GET")
	router.HandleFunc("/api/jobs", apiHandler.ListJobs).Methods("GET")
	router.HandleFunc("/api/jobs/{id}", apiHandler.GetJob).Methods("GET")
	router.HandleFunc("/api/workers", apiHandler.ListWorkers).Methods("GET")
	router.HandleFunc("/api/rounds/{id}/summary", apiHandler.GetRoundSummary).Methods("GET")

	// Middleware
	router.Use(loggingMiddleware)
	router.Use(corsMiddleware)

	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", viper.GetInt("server.http_port")),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Infof("HTTP server listening on port %d", viper.GetInt("server.http_port"))
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start HTTP server: %v", err)
		}
	}()

	return server
}

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.WithFields(logrus.Fields{
			"method":   r.Method,
			"path":     r.URL.Path,
			"duration": time.Since(start),
			"remote":   r.RemoteAddr,
		}).Info("HTTP request")
	})
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}