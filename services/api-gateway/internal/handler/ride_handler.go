package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/xebuonho/services/api-gateway/internal/grpcclient"
	"github.com/xebuonho/services/api-gateway/internal/middleware"
)

// RideHandler handles ride REST endpoints via gRPC
type RideHandler struct {
	client *grpcclient.RideClient
}

func NewRideHandler(client *grpcclient.RideClient) *RideHandler {
	return &RideHandler{client: client}
}

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

	ride, fare, err := h.client.CreateRide(r.Context(), grpcclient.CreateRideRequest{
		RiderID:        userID,
		PickupLat:      req.PickupLat,
		PickupLng:      req.PickupLng,
		PickupAddress:  req.PickupAddress,
		DropoffLat:     req.DropoffLat,
		DropoffLng:     req.DropoffLng,
		DropoffAddress: req.DropoffAddress,
		VehicleType:    req.VehicleType,
		PaymentMethod:  req.PaymentMethod,
		PromoCode:      req.PromoCode,
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"ride":          ride,
		"fare_estimate": fare,
	})
}

// GET /api/v1/rides/{id}
func (h *RideHandler) GetRide(w http.ResponseWriter, r *http.Request) {
	rideID := extractPathParam(r.URL.Path, "/api/v1/rides/")
	if rideID == "" {
		writeError(w, http.StatusBadRequest, "ride_id is required")
		return
	}

	ride, err := h.client.GetRide(r.Context(), rideID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, ride)
}

// PATCH /api/v1/rides/{id}/cancel
func (h *RideHandler) CancelRide(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/cancel")
	rideID := extractPathParam(path, "/api/v1/rides/")
	userRole := middleware.GetUserRole(r)

	var req struct {
		Reason string `json:"reason"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	cancelledBy := "rider"
	if userRole == "driver" {
		cancelledBy = "driver"
	}

	ride, err := h.client.CancelRide(r.Context(), rideID, cancelledBy, req.Reason)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, ride)
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

	estimates, err := h.client.EstimateFare(r.Context(), req.PickupLat, req.PickupLng, req.DropoffLat, req.DropoffLng, req.VehicleType)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{"estimates": estimates})
}

// GET /api/v1/rides?page=1&limit=20
func (h *RideHandler) ListRides(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	userRole := middleware.GetUserRole(r)
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 20
	}

	rides, total, err := h.client.ListRides(r.Context(), userID, userRole, page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"rides": rides,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}
