package handler

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/xebuonho/services/trip-service/internal/model"
	"github.com/xebuonho/services/trip-service/internal/service"
)

type TripHandler struct {
	svc       *service.TripService
	jwtSecret string
}

func NewTripHandler(svc *service.TripService, jwtSecret string) *TripHandler {
	return &TripHandler{svc: svc, jwtSecret: jwtSecret}
}

// Register mounts trip routes on the given mux.
func (h *TripHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("/trips", h.handleListTrips)
	mux.HandleFunc("/trips/", h.handleTrip)
	mux.HandleFunc("/drivers/", h.handleDriverSummary)
	mux.HandleFunc("/api/v1/trips", h.handleListTrips)
	mux.HandleFunc("/api/v1/trips/", h.handleTrip)
	mux.HandleFunc("/api/v1/drivers/", h.handleDriverSummary)
}

// handleListTrips — GET /trips?role=rider&service_type=ride&page=1&page_size=20
func (h *TripHandler) handleListTrips(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	userID, ok := h.authUser(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid authorization")
		return
	}

	q := r.URL.Query()
	role := q.Get("role")
	serviceType := q.Get("service_type")
	page, _ := strconv.Atoi(q.Get("page"))
	pageSize, _ := strconv.Atoi(q.Get("page_size"))

	trips, total, err := h.svc.ListTrips(r.Context(), userID, role, serviceType, page, pageSize)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if trips == nil {
		trips = []model.Trip{}
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"trips": trips,
		"total": total,
		"page":  page,
		"page_size": pageSize,
	})
}

// handleTrip — GET /trips/{id} | POST /trips/{id}/rating
func (h *TripHandler) handleTrip(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.authUser(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid authorization")
		return
	}

	// path: /trips/{id} or /trips/{id}/rating (supports /api/v1 prefix)
	cleanPath := strings.TrimPrefix(r.URL.Path, "/api/v1")
	parts := strings.Split(strings.Trim(cleanPath, "/"), "/")
	if len(parts) < 2 || parts[0] != "trips" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	tripID := parts[1]

	switch {
	case len(parts) == 2 && r.Method == http.MethodGet:
		trip, err := h.svc.GetTrip(r.Context(), tripID, userID)
		if err != nil {
			writeError(w, http.StatusNotFound, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, trip)

	case len(parts) == 3 && parts[2] == "rating" && r.Method == http.MethodPost:
		var req model.SubmitRatingRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if err := h.svc.SubmitRating(r.Context(), tripID, userID, req); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"message": "Đã ghi nhận đánh giá. Cảm ơn bạn!",
			"order_id": tripID,
			"rating":   req.Rating,
		})

	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

// handleDriverSummary — GET /drivers/{id}/rating-summary
func (h *TripHandler) handleDriverSummary(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	cleanPath := strings.TrimPrefix(r.URL.Path, "/api/v1")
	parts := strings.Split(strings.Trim(cleanPath, "/"), "/")
	if len(parts) != 3 || parts[0] != "drivers" || parts[2] != "rating-summary" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}

	summary, err := h.svc.GetRatingSummary(r.Context(), parts[1])
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, summary)
}

// authUser validates the Bearer JWT (same HS256 scheme as the gateway/user-service)
// and returns the user_id claim.
func (h *TripHandler) authUser(r *http.Request) (string, bool) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", false
	}
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return "", false
	}

	claims, err := validateJWT(parts[1], h.jwtSecret)
	if err != nil {
		return "", false
	}
	if claims.UserID == "" {
		return "", false
	}
	return claims.UserID, true
}

// claims mirrors the JWT payload produced by user-service.
type claims struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`
	Exp    int64  `json:"exp"`
	Iat    int64  `json:"iat"`
}

// validateJWT performs HMAC-SHA256 JWT validation (stdlib only, mirrors gateway middleware).
func validateJWT(tokenStr, secret string) (*claims, error) {
	parts := strings.Split(tokenStr, ".")
	if len(parts) != 3 {
		return nil, fmt.Errorf("invalid token format")
	}

	signingInput := parts[0] + "." + parts[1]
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signingInput))
	expectedSig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
	if !hmac.Equal([]byte(parts[2]), []byte(expectedSig)) {
		return nil, fmt.Errorf("invalid token signature")
	}

	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("invalid token payload")
	}

	var c claims
	if err := json.Unmarshal(payload, &c); err != nil {
		return nil, fmt.Errorf("invalid claims: %w", err)
	}
	if c.Exp > 0 && time.Now().Unix() > c.Exp {
		return nil, fmt.Errorf("token expired")
	}
	return &c, nil
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
