package handler

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/xebuonho/services/api-gateway/internal/middleware"
)

// RideHandler handles ride REST endpoints
type RideHandler struct{}

func NewRideHandler() *RideHandler { return &RideHandler{} }

// POST /api/v1/rides
func (h *RideHandler) CreateRide(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req struct {
		PickupLat      float64 `json:"pickup_lat"`
		PickupLng      float64 `json:"pickup_lng"`
		PickupAddress  string  `json:"pickup_address"`
		DropoffLat     float64 `json:"dropoff_lat"`
		DropoffLng     float64 `json:"dropoff_lng"`
		DropoffAddress string  `json:"dropoff_address"`
		VehicleType    string  `json:"vehicle_type"`
		PaymentMethod  string  `json:"payment_method"`
		PromoCode      string  `json:"promo_code"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.PickupLat == 0 || req.PickupLng == 0 || req.DropoffLat == 0 || req.DropoffLng == 0 {
		writeError(w, http.StatusBadRequest, "pickup and dropoff locations are required")
		return
	}

	idempotencyKey := r.Header.Get("X-Idempotency-Key")
	if idempotencyKey == "" {
		writeError(w, http.StatusBadRequest, "X-Idempotency-Key header is required")
		return
	}

	// In production: call ride-service via gRPC
	// rideClient.CreateRide(ctx, &pb.CreateRideRequest{...})
	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":              "ride-generated-uuid",
		"rider_id":        userID,
		"pickup_lat":      req.PickupLat,
		"pickup_lng":      req.PickupLng,
		"pickup_address":  req.PickupAddress,
		"dropoff_lat":     req.DropoffLat,
		"dropoff_lng":     req.DropoffLng,
		"dropoff_address": req.DropoffAddress,
		"vehicle_type":    req.VehicleType,
		"payment_method":  req.PaymentMethod,
		"status":          "created",
	})
}

// GET /api/v1/rides/{id}
func (h *RideHandler) GetRide(w http.ResponseWriter, r *http.Request) {
	rideID := extractPathParam(r.URL.Path, "/api/v1/rides/")
	if rideID == "" {
		writeError(w, http.StatusBadRequest, "ride_id is required")
		return
	}

	// In production: call ride-service via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":     rideID,
		"status": "created",
	})
}

// PATCH /api/v1/rides/{id}/cancel
func (h *RideHandler) CancelRide(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/cancel")
	rideID := extractPathParam(path, "/api/v1/rides/")

	var req struct {
		Reason string `json:"reason"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	// In production: call order-service CancelOrder via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":            rideID,
		"status":        "cancelled_by_customer",
		"cancel_reason": req.Reason,
	})
}

// POST /api/v1/rides/estimate
func (h *RideHandler) EstimateFare(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PickupLat   float64 `json:"pickup_lat"`
		PickupLng   float64 `json:"pickup_lng"`
		DropoffLat  float64 `json:"dropoff_lat"`
		DropoffLng  float64 `json:"dropoff_lng"`
		VehicleType string  `json:"vehicle_type"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// In production: call ride-service via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"vehicle_type":     req.VehicleType,
		"fare_estimate":    85000,
		"currency":         "VND",
		"surge_multiplier": 1.0,
	})
}

// GET /api/v1/rides?page=1&limit=20
func (h *RideHandler) ListRides(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	// In production: call ride-service ListRides via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"rides":    []interface{}{},
		"total":    0,
		"rider_id": userID,
	})
}
