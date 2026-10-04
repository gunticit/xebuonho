#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

mkdir -p logs bin

echo "🚀 Starting XeBuonHo microservices..."

# Load .env if present
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Function to start a service
start_service() {
  local name=$1
  local bin_path="bin/$name"
  shift
  
  # Kill existing instance if running
  pkill -f "$bin_path" 2>/dev/null || true

  echo "  ▶ Starting $name..."
  "$@" "$bin_path" > "logs/$name.log" 2>&1 &
  echo $! >> logs/pids.txt
}

> logs/pids.txt

# 1. Start core database / event services first
start_service "user-service" env HTTP_PORT=8091
start_service "merchant-service" env HTTP_PORT=8089 GRPC_PORT=50059
start_service "ride-service" env HTTP_PORT=8080 GRPC_PORT=50051
start_service "order-service" env HTTP_PORT=8088 GRPC_PORT=50058
start_service "notification-service" env HTTP_PORT=8092

# Wait 2 seconds for gRPC servers to initialize
sleep 2

# 2. Start auxiliary services
start_service "driver-service" env HTTP_PORT=8081 SERVICE_NAME=driver-service
start_service "payment-service" env HTTP_PORT=8087 SERVICE_NAME=payment-service
start_service "matching-service" env HTTP_PORT=8084 SERVICE_NAME=matching-service
start_service "location-service" env HTTP_PORT=8085 SERVICE_NAME=location-service
start_service "trip-service" env HTTP_PORT=8086 SERVICE_NAME=trip-service

# 3. Start API Gateway (depends on ride, order, merchant gRPC)
start_service "api-gateway" env HTTP_PORT=8000 \
  RIDE_SERVICE="localhost:50051" \
  ORDER_SERVICE="localhost:50058" \
  MERCHANT_SERVICE="localhost:50059" \
  USER_SERVICE_URL="http://localhost:8091"

echo "✅ All services started! Logs are in logs/*.log"
