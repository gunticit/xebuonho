package handler

import (
	"encoding/json"
	"net/http"
	"strings"
)

// MerchantHandler handles merchant REST endpoints
type MerchantHandler struct{}

func NewMerchantHandler() *MerchantHandler { return &MerchantHandler{} }

// GET /api/v1/merchants/nearby?lat=10.82&lng=106.63&radius=5&category=restaurant&sort=distance
func (h *MerchantHandler) ListNearbyMerchants(w http.ResponseWriter, r *http.Request) {
	lat := r.URL.Query().Get("lat")
	lng := r.URL.Query().Get("lng")

	if lat == "" || lng == "" {
		writeError(w, http.StatusBadRequest, "lat and lng query parameters are required")
		return
	}

	category := r.URL.Query().Get("category")
	sortBy := r.URL.Query().Get("sort")

	// In production: call merchant-service via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"merchants": []interface{}{},
		"total":     0,
		"category":  category,
		"sort":      sortBy,
	})
}

// GET /api/v1/merchants/{id}
func (h *MerchantHandler) GetMerchant(w http.ResponseWriter, r *http.Request) {
	merchantID := extractPathParam(r.URL.Path, "/api/v1/merchants/")
	if merchantID == "" || strings.Contains(merchantID, "/") {
		writeError(w, http.StatusBadRequest, "merchant_id is required")
		return
	}

	// In production: call merchant-service via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"id": merchantID,
	})
}

// GET /api/v1/merchants/{id}/menu
func (h *MerchantHandler) GetMenu(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/menu")
	merchantID := extractPathParam(path, "/api/v1/merchants/")
	if merchantID == "" {
		writeError(w, http.StatusBadRequest, "merchant_id is required")
		return
	}

	// In production: call merchant-service via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"merchant_id": merchantID,
		"categories":  []interface{}{},
	})
}

// GET /api/v1/merchants/search?q=pho&lat=10.82&lng=106.63
func (h *MerchantHandler) SearchMerchants(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		writeError(w, http.StatusBadRequest, "q (search query) is required")
		return
	}

	// In production: call merchant-service via gRPC
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"merchants": []interface{}{},
		"total":     0,
		"query":     query,
	})
}

// POST /api/v1/merchants (for merchant registration)
func (h *MerchantHandler) CreateMerchant(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        string  `json:"name"`
		Description string  `json:"description"`
		Category    string  `json:"category"`
		Phone       string  `json:"phone"`
		Latitude    float64 `json:"latitude"`
		Longitude   float64 `json:"longitude"`
		Address     string  `json:"address"`
		LogoURL     string  `json:"logo_url,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Name == "" || req.Category == "" {
		writeError(w, http.StatusBadRequest, "name and category are required")
		return
	}

	// In production: call merchant-service via gRPC
	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":       "merchant-generated-uuid",
		"name":     req.Name,
		"category": req.Category,
		"status":   "pending_verification",
	})
}

// POST /api/v1/merchants/{id}/menu
func (h *MerchantHandler) CreateMenuItem(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/menu")
	merchantID := extractPathParam(path, "/api/v1/merchants/")

	var req struct {
		CategoryName    string  `json:"category_name"`
		Name            string  `json:"name"`
		Description     string  `json:"description"`
		Price           float64 `json:"price"`
		ImageURL        string  `json:"image_url,omitempty"`
		PreparationTime int32   `json:"preparation_time_min"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Name == "" || req.Price <= 0 {
		writeError(w, http.StatusBadRequest, "name and valid price are required")
		return
	}

	// In production: call merchant-service via gRPC
	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":          "item-generated-uuid",
		"merchant_id": merchantID,
		"name":        req.Name,
		"price":       req.Price,
	})
}
