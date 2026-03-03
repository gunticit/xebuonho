#!/bin/bash
# ==============================================
# Test Script cho Xebuonho API Gateway
# Usage: ./scripts/test-api.sh
# ==============================================

set -e

BASE_URL="${API_URL:-http://localhost:8000}"
JWT_SECRET="${JWT_SECRET:-dev-secret}"

# Generate JWT token
TOKEN=$(python3 -c "
import json, hmac, hashlib, base64, time
h = base64.urlsafe_b64encode(json.dumps({'alg':'HS256','typ':'JWT'}).encode()).rstrip(b'=').decode()
p = base64.urlsafe_b64encode(json.dumps({'user_id':'user-test-123','role':'rider','exp':int(time.time())+3600,'iat':int(time.time())}).encode()).rstrip(b'=').decode()
s = base64.urlsafe_b64encode(hmac.new(b'${JWT_SECRET}', f'{h}.{p}'.encode(), hashlib.sha256).digest()).rstrip(b'=').decode()
print(f'{h}.{p}.{s}')
")

PASS=0
FAIL=0

check() {
    local name="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        echo "  ✅ $name"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $name (expected: $expected)"
        echo "     Got: $actual"
        FAIL=$((FAIL + 1))
    fi
}

echo "🧪 Testing Xebuonho API Gateway ($BASE_URL)"
echo "============================================="
echo ""

# ---- Public Endpoints ----
echo "📌 Public Endpoints"
R=$(curl -s $BASE_URL/health)
check "Health Check" '"status":"ok"' "$R"

R=$(curl -s "$BASE_URL/api/v1/merchants/nearby?lat=10.82&lng=106.63")
check "Merchants Nearby" '"merchants"' "$R"

R=$(curl -s "$BASE_URL/api/v1/merchants/search?q=pho")
check "Merchants Search" '"query":"pho"' "$R"

# ---- Auth Tests ----
echo ""
echo "🔒 Authentication"
R=$(curl -s $BASE_URL/api/v1/rides)
check "No Token → 401" '"error":"missing authorization header"' "$R"

R=$(curl -s $BASE_URL/api/v1/rides -H "Authorization: Bearer invalid.token.here")
check "Invalid Token → 401" '"error"' "$R"

EXPIRED=$(python3 -c "
import json, hmac, hashlib, base64
h = base64.urlsafe_b64encode(json.dumps({'alg':'HS256','typ':'JWT'}).encode()).rstrip(b'=').decode()
p = base64.urlsafe_b64encode(json.dumps({'user_id':'x','role':'rider','exp':1000}).encode()).rstrip(b'=').decode()
s = base64.urlsafe_b64encode(hmac.new(b'${JWT_SECRET}', f'{h}.{p}'.encode(), hashlib.sha256).digest()).rstrip(b'=').decode()
print(f'{h}.{p}.{s}')
")
R=$(curl -s $BASE_URL/api/v1/rides -H "Authorization: Bearer $EXPIRED")
check "Expired Token → 401" '"error":"token expired"' "$R"

# ---- Ride Endpoints ----
echo ""
echo "🚗 Rides"
R=$(curl -s -X POST $BASE_URL/api/v1/rides \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Idempotency-Key: test-ride-$(date +%s)" \
  -H "Content-Type: application/json" \
  -d '{"pickup_lat":10.77,"pickup_lng":106.70,"dropoff_lat":10.82,"dropoff_lng":106.63,"vehicle_type":"car"}')
check "Create Ride" '"status":"created"' "$R"

R=$(curl -s $BASE_URL/api/v1/rides/ride-123 -H "Authorization: Bearer $TOKEN")
check "Get Ride" '"id":"ride-123"' "$R"

R=$(curl -s -X PATCH $BASE_URL/api/v1/rides/ride-123/cancel \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"reason":"test"}')
check "Cancel Ride" '"cancelled_by_rider"' "$R"

R=$(curl -s -X POST $BASE_URL/api/v1/rides/estimate \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"pickup_lat":10.77,"pickup_lng":106.70,"dropoff_lat":10.82,"dropoff_lng":106.63}')
check "Estimate Fare" '"estimates"' "$R"

R=$(curl -s "$BASE_URL/api/v1/rides?page=1&limit=10" -H "Authorization: Bearer $TOKEN")
check "List Rides" '"rides"' "$R"

# ---- Order Endpoints ----
echo ""
echo "📦 Orders"
R=$(curl -s -X POST $BASE_URL/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Idempotency-Key: test-order-$(date +%s)" \
  -H "Content-Type: application/json" \
  -d '{"service_type":"food_delivery","pickup_lat":10.78,"pickup_lng":106.69,"dropoff_lat":10.77,"dropoff_lng":106.70,"items":[{"menu_item_id":"i1","quantity":2}]}')
check "Create Food Order" '"placed"' "$R"

R=$(curl -s -X POST $BASE_URL/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Idempotency-Key: test-grocery-$(date +%s)" \
  -H "Content-Type: application/json" \
  -d '{"service_type":"grocery","pickup_lat":10.78,"pickup_lng":106.69,"dropoff_lat":10.77,"dropoff_lng":106.70,"shopping_list":[{"name":"Rau","quantity":1,"unit":"bo","estimated_price":15000}]}')
check "Create Grocery Order" '"created"' "$R"

R=$(curl -s $BASE_URL/api/v1/orders/order-123 -H "Authorization: Bearer $TOKEN")
check "Get Order" '"id":"order-123"' "$R"

R=$(curl -s -X PATCH $BASE_URL/api/v1/orders/order-123/status \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"event":"driver_accepted"}')
check "Update Order Status" '"driver_accepted"' "$R"

# ---- Merchant Endpoints ----
echo ""
echo "🏪 Merchants"
R=$(curl -s -X POST $BASE_URL/api/v1/merchants \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Pho Test","category":"restaurant"}')
check "Create Merchant" '"name":"Pho Test"' "$R"

# ---- Validation ----
echo ""
echo "🛡️ Validation"
R=$(curl -s -X POST $BASE_URL/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}')
check "Missing service_type → 400" '"service_type is required"' "$R"

R=$(curl -s -X POST $BASE_URL/api/v1/rides \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"pickup_lat":10.77,"pickup_lng":106.70,"dropoff_lat":10.82,"dropoff_lng":106.63}')
check "Missing Idempotency Key → 400" '"X-Idempotency-Key"' "$R"

# ---- CORS ----
echo ""
echo "🌐 CORS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS $BASE_URL/api/v1/rides \
  -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: POST")
if [ "$STATUS" = "204" ]; then
    echo "  ✅ CORS Preflight → 204"
    PASS=$((PASS + 1))
else
    echo "  ❌ CORS Preflight (got $STATUS, expected 204)"
    FAIL=$((FAIL + 1))
fi

# ---- Summary ----
echo ""
echo "============================================="
echo "📊 Results: $PASS passed, $FAIL failed"
echo "============================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
