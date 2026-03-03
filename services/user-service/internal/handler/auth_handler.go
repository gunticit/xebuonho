package handler

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/xebuonho/services/user-service/internal/model"
	"github.com/xebuonho/services/user-service/internal/service"
)

// AuthHandler handles auth HTTP requests
type AuthHandler struct {
	authService *service.AuthService
	otpStore    map[string]otpEntry
	otpMu       sync.RWMutex
}

type otpEntry struct {
	Code      string
	ExpiresAt time.Time
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		otpStore:    make(map[string]otpEntry),
	}
}

// ServeHTTP routes auth requests
func (h *AuthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/auth")
	path = strings.TrimSuffix(path, "/")

	switch {
	case path == "/register" && r.Method == "POST":
		h.Register(w, r)
	case path == "/login" && r.Method == "POST":
		h.Login(w, r)
	case path == "/refresh" && r.Method == "POST":
		h.RefreshToken(w, r)
	case path == "/logout" && r.Method == "POST":
		h.Logout(w, r)
	case path == "/profile" && r.Method == "GET":
		h.GetProfile(w, r)
	case path == "/profile" && r.Method == "PATCH":
		h.UpdateProfile(w, r)
	case path == "/verify-otp" && r.Method == "POST":
		h.VerifyOTP(w, r)
	case path == "/resend-otp" && r.Method == "POST":
		h.ResendOTP(w, r)
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
	}
}

// Register handles user registration
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req model.RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := h.authService.Register(r.Context(), &req)
	if err != nil {
		code := http.StatusBadRequest
		if strings.Contains(err.Error(), "already registered") {
			code = http.StatusConflict
		}
		writeJSON(w, code, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusCreated, result)

	// Generate OTP for phone verification
	h.generateOTP(req.Phone)
}

// Login handles user login
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req model.LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := h.authService.Login(r.Context(), &req)
	if err != nil {
		code := http.StatusUnauthorized
		if strings.Contains(err.Error(), "is required") {
			code = http.StatusBadRequest
		}
		writeJSON(w, code, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// RefreshToken handles token refresh
func (h *AuthHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	var req model.RefreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	result, err := h.authService.RefreshToken(r.Context(), req.RefreshToken)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, result)
}

// Logout handles user logout
func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	userID := h.extractUserID(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	if err := h.authService.Logout(r.Context(), userID); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "logout failed"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "logged out"})
}

// GetProfile handles profile retrieval
func (h *AuthHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	userID := h.extractUserID(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	user, err := h.authService.GetProfile(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, &model.ProfileResponse{User: user})
}

// UpdateProfile handles profile update
func (h *AuthHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID := h.extractUserID(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req model.UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	user, err := h.authService.UpdateProfile(r.Context(), userID, &req)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, &model.ProfileResponse{User: user})
}

// extractUserID extracts user ID from JWT in Authorization header
func (h *AuthHandler) extractUserID(r *http.Request) string {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return ""
	}
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return ""
	}

	userID, _, err := h.authService.ValidateJWT(parts[1])
	if err != nil {
		return ""
	}
	return userID
}

func writeJSON(w http.ResponseWriter, code int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(data)
}

// ==========================================
// OTP Methods
// ==========================================

func (h *AuthHandler) generateOTP(phone string) string {
	b := make([]byte, 3)
	rand.Read(b)
	code := fmt.Sprintf("%06d", int(b[0])<<16|int(b[1])<<8|int(b[2])%1000000)
	code = code[:6]

	h.otpMu.Lock()
	h.otpStore[phone] = otpEntry{
		Code:      code,
		ExpiresAt: time.Now().Add(5 * time.Minute),
	}
	h.otpMu.Unlock()

	log.Printf("[otp] 📱 OTP for %s: %s (expires in 5 min)", phone, code)
	return code
}

// VerifyOTP verifies the OTP code
func (h *AuthHandler) VerifyOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Phone string `json:"phone"`
		Code  string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request"})
		return
	}

	// Demo mode: accept "123456"
	if req.Code == "123456" {
		log.Printf("[otp] ✅ Demo OTP verified for %s", req.Phone)
		writeJSON(w, http.StatusOK, map[string]string{"status": "verified"})
		return
	}

	h.otpMu.RLock()
	entry, exists := h.otpStore[req.Phone]
	h.otpMu.RUnlock()

	if !exists {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Mã OTP không tồn tại. Vui lòng gửi lại."})
		return
	}

	if time.Now().After(entry.ExpiresAt) {
		h.otpMu.Lock()
		delete(h.otpStore, req.Phone)
		h.otpMu.Unlock()
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Mã OTP đã hết hạn. Vui lòng gửi lại."})
		return
	}

	if entry.Code != req.Code {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Mã OTP không đúng"})
		return
	}

	// OTP verified - delete it
	h.otpMu.Lock()
	delete(h.otpStore, req.Phone)
	h.otpMu.Unlock()

	log.Printf("[otp] ✅ OTP verified for %s", req.Phone)
	writeJSON(w, http.StatusOK, map[string]string{"status": "verified"})
}

// ResendOTP resends OTP to phone
func (h *AuthHandler) ResendOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Phone string `json:"phone"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request"})
		return
	}

	code := h.generateOTP(req.Phone)
	log.Printf("[otp] 🔄 OTP resent for %s: %s", req.Phone, code)
	writeJSON(w, http.StatusOK, map[string]string{"status": "sent"})
}
