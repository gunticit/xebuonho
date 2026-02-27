package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/xebuonho/services/api-gateway/internal/grpcclient"
	"github.com/xebuonho/services/api-gateway/internal/middleware"
)

// MerchantHandler handles merchant REST endpoints via gRPC
type MerchantHandler struct {
	client *grpcclient.MerchantClient
}

func NewMerchantHandler(client *grpcclient.MerchantClient) *MerchantHandler {
	return &MerchantHandler{client: client}
}

// GET /api/v1/merchants/nearby?lat=10.82&lng=106.63&radius=5&category=restaurant&sort=distance
func (h *MerchantHandler) ListNearbyMerchants(w http.ResponseWriter, r *http.Request) {
	lat, _ := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lng, _ := strconv.ParseFloat(r.URL.Query().Get("lng"), 64)

	if lat == 0 || lng == 0 {
		writeError(w, http.StatusBadRequest, "lat and lng query parameters are required")
		return
	}

	radiusKm, _ := strconv.ParseFloat(r.URL.Query().Get("radius"), 64)
	category := r.URL.Query().Get("category")
	sortBy := r.URL.Query().Get("sort")
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 20
	}

	merchants, total, err := h.client.ListNearby(r.Context(), lat, lng, radiusKm, category, sortBy, page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"merchants": merchants,
		"total":     total,
		"page":      page,
		"limit":     limit,
	})
}

// GET /api/v1/merchants/{id}
func (h *MerchantHandler) GetMerchant(w http.ResponseWriter, r *http.Request) {
	merchantID := extractPathParam(r.URL.Path, "/api/v1/merchants/")
	if merchantID == "" || strings.Contains(merchantID, "/") {
		writeError(w, http.StatusBadRequest, "merchant_id is required")
		return
	}

	merchant, err := h.client.GetMerchant(r.Context(), merchantID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, merchant)
}

// GET /api/v1/merchants/{id}/menu
func (h *MerchantHandler) GetMenu(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/menu")
	merchantID := extractPathParam(path, "/api/v1/merchants/")
	if merchantID == "" {
		writeError(w, http.StatusBadRequest, "merchant_id is required")
		return
	}

	categories, err := h.client.GetMenu(r.Context(), merchantID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"merchant_id": merchantID,
		"categories":  categories,
	})
}

// GET /api/v1/merchants/search?q=pho&lat=10.82&lng=106.63
func (h *MerchantHandler) SearchMerchants(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		writeError(w, http.StatusBadRequest, "q (search query) is required")
		return
	}

	lat, _ := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lng, _ := strconv.ParseFloat(r.URL.Query().Get("lng"), 64)
	radiusKm, _ := strconv.ParseFloat(r.URL.Query().Get("radius"), 64)
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 20
	}

	merchants, total, err := h.client.SearchMerchants(r.Context(), query, lat, lng, radiusKm, page, limit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"merchants": merchants,
		"total":     total,
		"query":     query,
	})
}

// POST /api/v1/merchants
func (h *MerchantHandler) CreateMerchant(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

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

	merchant, err := h.client.CreateMerchant(r.Context(), userID, req.Name, req.Description, req.Category, req.Phone, req.Address, req.Latitude, req.Longitude, req.LogoURL)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, merchant)
}

// POST /api/v1/merchants/{id}/menu
func (h *MerchantHandler) CreateMenuItem(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimSuffix(r.URL.Path, "/menu")
	merchantID := extractPathParam(path, "/api/v1/merchants/")

	var req struct {
		CategoryName string  `json:"category_name"`
		Name         string  `json:"name"`
		Description  string  `json:"description"`
		Price        float64 `json:"price"`
		ImageURL     string  `json:"image_url,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Name == "" || req.Price <= 0 {
		writeError(w, http.StatusBadRequest, "name and valid price are required")
		return
	}

	item, err := h.client.CreateMenuItem(r.Context(), merchantID, req.CategoryName, req.Name, req.Description, req.Price, req.ImageURL)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, item)
}
