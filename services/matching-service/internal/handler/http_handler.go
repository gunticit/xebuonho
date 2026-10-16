package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/xebuonho/services/matching-service/internal/model"
	"github.com/xebuonho/services/matching-service/internal/service"
)

// HTTPHandler exposes REST endpoints for matching-service
type HTTPHandler struct {
	svc service.MatchingService
}

// NewHTTPHandler creates a new HTTPHandler
func NewHTTPHandler(svc service.MatchingService) *HTTPHandler {
	return &HTTPHandler{svc: svc}
}

// RegisterRoutes registers endpoints on http.ServeMux
func (h *HTTPHandler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/health", h.Health)
	mux.HandleFunc("/api/v1/match", h.MatchDriver)
	mux.HandleFunc("/api/v1/drivers/nearby", h.FindNearbyDrivers)
}

// Health checks service status
func (h *HTTPHandler) Health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "matching-service",
	})
}

// MatchDriver matches the best driver for an order
func (h *HTTPHandler) MatchDriver(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var req model.MatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body: " + err.Error()})
		return
	}

	if req.PickupLat == 0 && req.PickupLng == 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "pickup_lat and pickup_lng are required"})
		return
	}

	res, err := h.svc.MatchDriver(r.Context(), req)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, res)
}

// FindNearbyDrivers finds drivers near coordinates
func (h *HTTPHandler) FindNearbyDrivers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	q := r.URL.Query()
	latStr := q.Get("lat")
	lngStr := q.Get("lng")
	if latStr == "" || lngStr == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "lat and lng query params are required"})
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid lat"})
		return
	}

	lng, err := strconv.ParseFloat(lngStr, 64)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid lng"})
		return
	}

	radius, _ := strconv.ParseFloat(q.Get("radius"), 64)
	limit, _ := strconv.Atoi(q.Get("limit"))
	serviceType := q.Get("service_type")

	drivers, err := h.svc.FindNearbyDrivers(r.Context(), lat, lng, radius, serviceType, limit)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"count":   len(drivers),
		"drivers": drivers,
	})
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}
