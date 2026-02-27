package handler

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/xebuonho/services/api-gateway/internal/middleware"
)

// OrderHandler handles unified order REST endpoints
type OrderHandler struct{}

func NewOrderHandler() *OrderHandler { return &OrderHandler{} }

// POST /api/v1/orders
func (h *OrderHandler) CreateOrder(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req struct {
		ServiceType    string  `json:"service_type"` // food_delivery, grocery, designated_driver
		MerchantID     string  `json:"merchant_id,omitempty"`
		PickupLat      float64 `json:"pickup_lat"`
		PickupLng      float64 `json:"pickup_lng"`
		PickupAddress  string  `json:"pickup_address"`
		DropoffLat     float64 `json:"dropoff_lat"`
		DropoffLng     float64 `json:"dropoff_lng"`
		DropoffAddress string  `json:"dropoff_address"`
		PaymentMethod  string  `json:"payment_method"`
		PromoCode      string  `json:"promo_code,omitempty"`
		Items          []struct {
			MenuItemID string `json:"menu_item_id"`
			Quantity   int32  `json:"quantity"`
			Notes      string `json:"notes,omitempty"`
		} `json:"items,omitempty"`
		ShoppingList []struct {
			Name              string  `json:"name"`
			Quantity          int32   `json:"quantity"`
			Unit              string  `json:"unit"`
			EstimatedPrice    float64 `json:"estimated_price"`
			Notes             string  `json:"notes,omitempty"`
			AllowSubstitution bool    `json:"allow_substitution"`
		} `json:"shopping_list,omitempty"`
		DesignatedOptions *struct {
			ShadowMode   string `json:"shadow_mode"`
			VehicleType  string `json:"vehicle_type"`
			LicensePlate string `json:"license_plate"`
		} `json:"designated_options,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.ServiceType == "" {
		writeError(w, http.StatusBadRequest, "service_type is required")
		return
	}

	validTypes := map[string]bool{"food_delivery": true, "grocery": true, "designated_driver": true}
	if !validTypes[req.ServiceType] {
		writeError(w, http.StatusBadRequest, "service_type must be: food_delivery, grocery, or designated_driver")
		return
	}

	idempotencyKey := r.Header.Get("X-Idempotency-Key")
	if idempotencyKey == "" {
		writeError(w, http.StatusBadRequest, "X-Idempotency-Key header is required")
		return
	}

	// In production: call order-service via gRPC
	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":           "order-generated-uuid",
		"customer_id":  userID,
		"service_type": req.ServiceType,
		"status":       initialStatus(req.ServiceType),
	})
}

// GET /api/v1/orders/{id}
func (h *OrderHandler) GetOrder(w http.ResponseWriter, r *http.Request) {
	orderID := extractPathParam(r.URL.Path, "/api/v1/orders/")
	if orderID == "" || strings.Contains(orderID, "/") {
		writeError(w, http.StatusBadRequest, "order_id is required")
		return
	}

	// In production: call order-service via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":     orderID,
		"status": "created",
	})
}

// PATCH /api/v1/orders/{id}/status
func (h *OrderHandler) UpdateOrderStatus(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/status")
	orderID := extractPathParam(path, "/api/v1/orders/")
	userID := middleware.GetUserID(r)
	userRole := middleware.GetUserRole(r)

	var req struct {
		Event string `json:"event"` // driver_found, driver_accepted, etc.
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Event == "" {
		writeError(w, http.StatusBadRequest, "event is required")
		return
	}

	// In production: call order-service UpdateOrderStatus via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":         orderID,
		"event":      req.Event,
		"actor_id":   userID,
		"actor_role": userRole,
	})
}

// PATCH /api/v1/orders/{id}/cancel
func (h *OrderHandler) CancelOrder(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/cancel")
	orderID := extractPathParam(path, "/api/v1/orders/")
	userRole := middleware.GetUserRole(r)

	var req struct {
		Reason string `json:"reason"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	cancelledBy := "customer"
	if userRole == "driver" {
		cancelledBy = "driver"
	}

	// In production: call order-service CancelOrder via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id":            orderID,
		"status":        "cancelled_by_" + cancelledBy,
		"cancel_reason": req.Reason,
	})
}

// GET /api/v1/orders?service_type=food_delivery&page=1&limit=20
func (h *OrderHandler) ListOrders(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	userRole := middleware.GetUserRole(r)
	serviceType := r.URL.Query().Get("service_type")

	// In production: call order-service ListOrders via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"orders":       []interface{}{},
		"total":        0,
		"user_id":      userID,
		"role":         userRole,
		"service_type": serviceType,
	})
}

// POST /api/v1/orders/estimate
func (h *OrderHandler) EstimatePrice(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ServiceType string  `json:"service_type"`
		VehicleType string  `json:"vehicle_type,omitempty"`
		DistanceKm  float64 `json:"distance_km"`
		DurationMin int     `json:"duration_minutes"`
		ItemsTotal  float64 `json:"items_total,omitempty"`
		IsDuo       bool    `json:"is_duo,omitempty"`
		IsNight     bool    `json:"is_night,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	// In production: call order-service EstimatePrice via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"service_type":   req.ServiceType,
		"total_estimate": 0,
		"currency":       "VND",
	})
}

func initialStatus(serviceType string) string {
	if serviceType == "food_delivery" {
		return "placed"
	}
	return "created"
}
