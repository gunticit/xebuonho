package handler

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/xebuonho/services/user-service/internal/model"
	"github.com/xebuonho/services/user-service/internal/service"
)

// AuthHandler handles auth HTTP requests
type AuthHandler struct {
	authService *service.AuthService
	redisClient *redis.Client
	otpStore    map[string]otpEntry
	otpMu       sync.RWMutex
}

type otpEntry struct {
	Code      string
	ExpiresAt time.Time
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(authService *service.AuthService, redisClient *redis.Client) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		redisClient: redisClient,
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
	case (path == "/profile" || path == "/account") && r.Method == "DELETE":
		h.DeleteAccount(w, r)
	case path == "/verify-otp" && r.Method == "POST":
		h.VerifyOTP(w, r)
	case path == "/resend-otp" && r.Method == "POST":
		h.ResendOTP(w, r)
	case path == "/driver/kyc" && r.Method == "POST":
		h.SubmitDriverKYC(w, r)
	case path == "/driver/kyc" && r.Method == "GET":
		h.GetMyKYC(w, r)
	case path == "/uploads/presign" && r.Method == "POST":
		h.PresignUpload(w, r)
	case path == "/admin/drivers" && r.Method == "GET":
		h.AdminListDrivers(w, r)
	case strings.HasPrefix(path, "/admin/drivers/") && strings.HasSuffix(path, "/approval") && r.Method == "PATCH":
		h.AdminDriverApproval(w, r)
	case strings.HasPrefix(path, "/admin/drivers/") && r.Method == "GET":
		h.AdminDriverDetail(w, r)
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

// SubmitDriverKYC handles driver KYC submission
func (h *AuthHandler) SubmitDriverKYC(w http.ResponseWriter, r *http.Request) {
	userID := h.extractUserID(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req model.DriverKYCRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	if err := h.authService.SubmitDriverKYC(r.Context(), userID, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "pending_approval",
		"message": "Hồ sơ đối tác tài xế đã được ghi nhận và đang chờ đội ngũ kiểm duyệt.",
	})
}

// AdminDriverApproval handles admin approving/rejecting a driver
func (h *AuthHandler) AdminDriverApproval(w http.ResponseWriter, r *http.Request) {
	adminID, ok := h.requireAdmin(w, r)
	if !ok {
		return
	}

	// path format: /api/v1/auth/admin/drivers/{id}/approval
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if len(parts) < 4 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid path"})
		return
	}
	driverID := parts[len(parts)-2]

	var req model.DriverApprovalRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	// Audit trail: record which admin made the decision (NĐ 10/2020 traceability)
	if err := h.authService.UpdateDriverApprovalStatusBy(r.Context(), driverID, req.Status, req.Reason, adminID); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"driver_id": driverID,
		"status":    req.Status,
		"message":   fmt.Sprintf("Trạng thái phê duyệt đối tác tài xế đã được cập nhật thành %s", req.Status),
	})
}

// PresignUpload returns a presigned PUT URL for KYC document upload
func (h *AuthHandler) PresignUpload(w http.ResponseWriter, r *http.Request) {
	userID := h.extractUserID(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var req model.PresignUploadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	resp, err := h.authService.PresignUpload(r.Context(), userID, &req)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

// AdminListDrivers returns the KYC moderation queue (admin only)
func (h *AuthHandler) AdminListDrivers(w http.ResponseWriter, r *http.Request) {
	if _, ok := h.requireAdmin(w, r); !ok {
		return
	}

	list, err := h.authService.ListDriversForAdmin(r.Context(),
		r.URL.Query().Get("status"), r.URL.Query().Get("kind"))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{"drivers": list})
}

// GetMyKYC returns the driver's own KYC submission (fields + presigned doc URLs)
func (h *AuthHandler) GetMyKYC(w http.ResponseWriter, r *http.Request) {
	userID := h.extractUserID(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	detail, err := h.authService.GetDriverDetail(r.Context(), userID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "chưa có hồ sơ KYC cho tài khoản này"})
		return
	}

	writeJSON(w, http.StatusOK, detail)
}

// AdminDriverDetail returns a driver profile with presigned document URLs (admin only)
func (h *AuthHandler) AdminDriverDetail(w http.ResponseWriter, r *http.Request) {
	if _, ok := h.requireAdmin(w, r); !ok {
		return
	}

	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	driverID := parts[len(parts)-1]
	if driverID == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid path"})
		return
	}

	detail, err := h.authService.GetDriverDetail(r.Context(), driverID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, detail)
}

// requireAdmin enforces admin role for moderation endpoints. Returns the admin's
// user ID for audit logging; writes the error response and returns false on failure.
func (h *AuthHandler) requireAdmin(w http.ResponseWriter, r *http.Request) (string, bool) {
	userID, role := h.extractAuth(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return "", false
	}
	if role != "admin" {
		writeJSON(w, http.StatusForbidden, map[string]string{"error": "admin access required"})
		return "", false
	}
	return userID, true
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

// DeleteAccount handles account deletion request
func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID := h.extractUserID(r)
	if userID == "" {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	var token string
	authHeader := r.Header.Get("Authorization")
	if strings.HasPrefix(strings.ToLower(authHeader), "bearer ") {
		token = strings.TrimSpace(authHeader[7:])
	}

	if err := h.authService.DeleteAccount(r.Context(), userID, token); err != nil {
		status := http.StatusInternalServerError
		if strings.Contains(err.Error(), "active_order_conflict") {
			status = http.StatusConflict
		}
		writeJSON(w, status, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":  "success",
		"message": "Tài khoản của bạn đã được xóa thành công. Toàn bộ thông tin cá nhân và phiên đăng nhập đã được hủy bỏ.",
	})
}

// extractUserID extracts user ID from JWT in Authorization header
func (h *AuthHandler) extractUserID(r *http.Request) string {
	userID, _ := h.extractAuth(r)
	return userID
}

// extractAuth extracts user ID and role from a validated JWT in Authorization header
func (h *AuthHandler) extractAuth(r *http.Request) (string, string) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", ""
	}
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return "", ""
	}

	userID, role, err := h.authService.ValidateJWT(parts[1])
	if err != nil {
		return "", ""
	}
	return userID, role
}

func writeJSON(w http.ResponseWriter, code int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(data)
}

// ==========================================
// OTP Methods (Redis backed with in-memory fallback)
// ==========================================

func (h *AuthHandler) generateOTP(phone string) string {
	b := make([]byte, 3)
	rand.Read(b)
	code := fmt.Sprintf("%06d", int(b[0])<<16|int(b[1])<<8|int(b[2])%1000000)
	code = code[:6]

	ctx := context.Background()

	// 1. If Redis is available, store in Redis with TTL 5 minutes
	if h.redisClient != nil {
		otpKey := fmt.Sprintf("otp:%s", phone)
		rateKey := fmt.Sprintf("otp:rate:%s", phone)

		// Set OTP code with 5-minute expiration
		_ = h.redisClient.Set(ctx, otpKey, code, 5*time.Minute).Err()
		// Set rate-limit key with 60-second cooldown
		_ = h.redisClient.Set(ctx, rateKey, "1", 60*time.Second).Err()

		log.Printf("[otp] 📱 [Redis] OTP for %s: %s (expires in 5m)", phone, code)
		return code
	}

	// 2. In-memory fallback
	h.otpMu.Lock()
	h.otpStore[phone] = otpEntry{
		Code:      code,
		ExpiresAt: time.Now().Add(5 * time.Minute),
	}
	h.otpMu.Unlock()

	log.Printf("[otp] 📱 [In-Memory] OTP for %s: %s (expires in 5m)", phone, code)
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

	ctx := r.Context()

	// 1. Verify via Redis if available (Atomic Lua script: verify and delete)
	if h.redisClient != nil {
		otpKey := fmt.Sprintf("otp:%s", req.Phone)
		luaScript := `
			local val = redis.call('get', KEYS[1])
			if not val then
				return -1
			end
			if val == ARGV[1] then
				redis.call('del', KEYS[1])
				return 1
			else
				return 0
			end
		`
		res, err := h.redisClient.Eval(ctx, luaScript, []string{otpKey}, req.Code).Int()
		if err == nil {
			switch res {
			case 1:
				log.Printf("[otp] ✅ [Redis] OTP verified for %s", req.Phone)
				writeJSON(w, http.StatusOK, map[string]string{"status": "verified"})
				return
			case 0:
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Mã OTP không đúng"})
				return
			default:
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Mã OTP đã hết hạn hoặc không tồn tại. Vui lòng gửi lại."})
				return
			}
		}
	}

	// 2. In-memory fallback verification
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

	log.Printf("[otp] ✅ [In-Memory] OTP verified for %s", req.Phone)
	writeJSON(w, http.StatusOK, map[string]string{"status": "verified"})
}

// ResendOTP resends OTP to phone with rate limiting (60s cooldown)
func (h *AuthHandler) ResendOTP(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Phone string `json:"phone"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request"})
		return
	}

	// Rate-limit check via Redis
	if h.redisClient != nil {
		rateKey := fmt.Sprintf("otp:rate:%s", req.Phone)
		exists, _ := h.redisClient.Exists(r.Context(), rateKey).Result()
		if exists > 0 {
			ttl, _ := h.redisClient.TTL(r.Context(), rateKey).Result()
			writeJSON(w, http.StatusTooManyRequests, map[string]string{
				"error": fmt.Sprintf("Vui lòng đợi %d giây trước khi yêu cầu mã OTP mới", int(ttl.Seconds())),
			})
			return
		}
	}

	code := h.generateOTP(req.Phone)
	log.Printf("[otp] 🔄 OTP resent for %s: %s", req.Phone, code)
	writeJSON(w, http.StatusOK, map[string]string{"status": "sent"})
}
