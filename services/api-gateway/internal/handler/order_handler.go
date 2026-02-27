package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/xebuonho/services/api-gateway/internal/grpcclient"
	"github.com/xebuonho/services/api-gateway/internal/middleware"
)

// OrderHandler handles unified order REST endpoints via gRPC
type OrderHandler struct {
	client *grpcclient.OrderClient
}

func NewOrderHandler(client *grpcclient.OrderClient) *OrderHandler {
	return &OrderHandler{client: client}
}

// POST /api/v1/orders
func (h *OrderHandler) CreateOrder(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var req struct {
		ServiceType    string  `json:"service_type"`
		MerchantID     string  `json:"merchant_id,omitempty"`
		PickupLat      float64 `json:"pickup_lat"`
		PickupLng      float64 `json:"pickup_lng"`
		PickupAddress  string  `json:"pickup_address"`
		DropoffLat     float64 `json:"dropoff_lat"`
		DropoffLng     float64 `json:"dropoff_lng"`
		DropoffAddress string  `json:"dropoff_address"`
		PaymentMethod  string  `json:"payment_method"`
		PromoCode      string  `json:"promo_code,omitempty"`
		VehicleType    string  `json:"vehicle_type,omitempty"`
		Items          []struct {
			MenuItemID string `json:"menu_item_id"`
			Quantity   int32  `json:"quantity"`
			Notes      string `json:"notes,omitempty"`
		} `json:"items,omitempty"`
		ShoppingList []struct {
			Name           string  `json:"name"`
			Quantity       int32   `json:"quantity"`
			Unit           string  `json:"unit"`
			EstimatedPrice float64 `json:"estimated_price"`
			Notes          string  `json:"notes,omitempty"`
		} `json:"shopping_list,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.ServiceType == "" {
		writeError(w, http.StatusBadRequest, "service_type is required")
		return
	}

	idempotencyKey := r.Header.Get("X-Idempotency-Key")
	if idempotencyKey == "" {
		writeError(w, http.StatusBadRequest, "X-Idempotency-Key header is required")
		return
	}

	// Build gRPC request
	grpcReq := grpcclient.CreateOrderReq{
		ServiceType:    req.ServiceType,
		CustomerID:     userID,
		IdempotencyKey: idempotencyKey,
		PickupLat:      req.PickupLat,
		PickupLng:      req.PickupLng,
		PickupAddress:  req.PickupAddress,
		DropoffLat:     req.DropoffLat,
		DropoffLng:     req.DropoffLng,
		DropoffAddress: req.DropoffAddress,
		VehicleType:    req.VehicleType,
		MerchantID:     req.MerchantID,
		PaymentMethod:  req.PaymentMethod,
		PromoCode:      req.PromoCode,
	}

	for _, item := range req.Items {
		grpcReq.Items = append(grpcReq.Items, grpcclient.OrderItemReq{
			MenuItemID: item.MenuItemID,
			Quantity:   item.Quantity,
			Notes:      item.Notes,
		})
	}
	for _, sl := range req.ShoppingList {
		grpcReq.ShoppingList = append(grpcReq.ShoppingList, grpcclient.ShoppingListReq{
			Name:           sl.Name,
			Quantity:       sl.Quantity,
			Unit:           sl.Unit,
			EstimatedPrice: sl.EstimatedPrice,
			Notes:          sl.Notes,
		})
	}

	order, price, err := h.client.CreateOrder(r.Context(), grpcReq)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"order":           order,
		"price_breakdown": price,
	})
}

// GET /api/v1/orders/{id}
func (h *OrderHandler) GetOrder(w http.ResponseWriter, r *http.Request) {
	orderID := extractPathParam(r.URL.Path, "/api/v1/orders/")
	if orderID == "" || strings.Contains(orderID, "/") {
		writeError(w, http.StatusBadRequest, "order_id is required")
		return
	}

	order, err := h.client.GetOrder(r.Context(), orderID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, order)
}

// PATCH /api/v1/orders/{id}/status
func (h *OrderHandler) UpdateOrderStatus(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/status")
	orderID := extractPathParam(path, "/api/v1/orders/")
	userID := middleware.GetUserID(r)
	userRole := middleware.GetUserRole(r)

	var req struct {
		Event string `json:"event"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Event == "" {
		writeError(w, http.StatusBadRequest, "event is required")
		return
	}

	order, err := h.client.UpdateOrderStatus(r.Context(), orderID, userID, userRole, req.Event)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, order)
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

	order, err := h.client.CancelOrder(r.Context(), orderID, cancelledBy, req.Reason)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, order)
}

// GET /api/v1/orders?service_type=food_delivery&page=1&limit=20
func (h *OrderHandler) ListOrders(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	userRole := middleware.GetUserRole(r)
	serviceType := r.URL.Query().Get("service_type")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 20
	}

	orders, total, err := h.client.ListOrders(r.Context(), userID, userRole, serviceType, page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"orders": orders,
		"total":  total,
		"page":   page,
		"limit":  limit,
	})
}

// POST /api/v1/orders/estimate
func (h *OrderHandler) EstimatePrice(w http.ResponseWriter, r *http.Request) {
	var req struct {
		ServiceType string  `json:"service_type"`
		VehicleType string  `json:"vehicle_type,omitempty"`
		DistanceKm  float64 `json:"distance_km"`
		ItemsTotal  float64 `json:"items_total,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	price, err := h.client.EstimatePrice(r.Context(), req.ServiceType, req.VehicleType, req.DistanceKm, req.ItemsTotal)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, price)
}
