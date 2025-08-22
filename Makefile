# SPDX-License-Identifier: MIT

.PHONY: all build test clean setup

all: build

setup:
	@echo "Setting up development environment..."
	@./scripts/setup.sh

build: build-contracts build-relay build-workers build-dashboard

build-contracts:
	@echo "Building smart contracts..."
	@cd contracts/wargame && make

build-relay:
	@echo "Building relay service..."
	@cd relay && go build -o bin/relay ./src

build-workers:
	@echo "Building workers..."
	@cd workers/attacker && cargo build --release
	@cd workers/defender && cargo build --release

build-dashboard:
	@echo "Building dashboard..."
	@cd dashboard && npm install && npm run build

test: test-unit test-integration test-e2e

test-unit:
	@echo "Running unit tests..."
	@cd relay && go test ./...
	@cd workers/attacker && cargo test
	@cd workers/defender && cargo test
	@cd dashboard && npm test

test-integration:
	@echo "Running integration tests..."
	@cd tests/integration && python -m pytest

test-e2e:
	@echo "Running e2e tests..."
	@cd tests/e2e && python -m pytest
	@./scripts/assert_determinism.sh
	@./scripts/assert_no_egress.sh

clean:
	@echo "Cleaning build artifacts..."
	@find . -name "target" -type d -exec rm -rf {} +
	@find . -name "node_modules" -type d -exec rm -rf {} +
	@find . -name "*.log" -type f -delete
	@rm -rf minio-data/
	@rm -rf sandbox/vms/
	@rm -rf artifacts/

docker-up:
	@cd ops && docker-compose up -d

docker-down:
	@cd ops && docker-compose down

run-round:
	@./scripts/run_round.sh