.PHONY: all proto build test lint run-all docker-up docker-down clean

# ============================================
# DEVELOPMENT
# ============================================

## Start all infrastructure (Redis, PostgreSQL, Kafka, EMQX)
docker-up:
	docker-compose -f deployments/docker-compose.dev.yml up -d

## Stop all infrastructure
docker-down:
	docker-compose -f deployments/docker-compose.dev.yml down

## Run all services (development mode)
run-all:
	@echo "Starting all services..."
	@for service in ride-service driver-service user-service payment-service \
		matching-service location-service trip-service notification-service \
		order-service merchant-service; do \
		echo "Starting $$service..."; \
		cd services/$$service && go run cmd/main.go & \
		cd ../..; \
	done
	@echo "All services started!"

# ============================================
# BUILD
# ============================================

## Build all services
build:
	@for service in ride-service driver-service user-service payment-service \
		matching-service location-service trip-service notification-service \
		order-service merchant-service; do \
		echo "Building $$service..."; \
		cd services/$$service && go build -o ../../bin/$$service ./cmd/main.go; \
		cd ../..; \
	done

## Build single service: make build-service SERVICE=ride-service
build-service:
	cd services/$(SERVICE) && go build -o ../../bin/$(SERVICE) ./cmd/main.go

# ============================================
# PROTO (gRPC code generation)
# ============================================

## Generate all gRPC code from proto files
proto:
	@echo "Generating gRPC code..."
	@for dir in proto/*/; do \
		protoc --go_out=. --go-grpc_out=. $$dir*.proto; \
	done
	@echo "gRPC code generated!"

# ============================================
# TESTING
# ============================================

## Run all tests
test:
	go test -v -race -coverprofile=coverage.out ./...

## Test single service
test-service:
	cd services/$(SERVICE) && go test -v -race -coverprofile=coverage.out ./...

# ============================================
# QUALITY
# ============================================

## Run linter
lint:
	golangci-lint run ./...

## Format code
fmt:
	gofmt -s -w .
	goimports -w .

## Tidy go modules
tidy:
	@for dir in services/*/; do \
		echo "Tidying $$dir..."; \
		cd $$dir && go mod tidy; \
		cd ../..; \
	done
	cd pkg && go mod tidy

# ============================================
# DATABASE
# ============================================

## Run migrations up
migrate-up:
	@for service in ride-service driver-service user-service payment-service trip-service \
		order-service merchant-service; do \
		echo "Migrating $$service..."; \
		migrate -path services/$$service/migrations \
			-database "$(DATABASE_URL)" up; \
	done

## Run migrations down
migrate-down:
	migrate -path services/$(SERVICE)/migrations -database "$(DATABASE_URL)" down 1

## Create new migration
migrate-create:
	migrate create -ext sql -dir services/$(SERVICE)/migrations -seq $(NAME)

# ============================================
# CLEAN
# ============================================

clean:
	rm -rf bin/
	rm -f coverage.out
