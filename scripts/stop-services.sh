#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🛑 Stopping all XeBuonHo microservices..."

for service in api-gateway ride-service driver-service user-service payment-service \
  matching-service location-service trip-service notification-service \
  order-service merchant-service; do
  pkill -f "bin/$service" 2>/dev/null && echo "  ✔ Stopped $service" || true
done

rm -f logs/pids.txt
echo "✅ All microservices stopped."
