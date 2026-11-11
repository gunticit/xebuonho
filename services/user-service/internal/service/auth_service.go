package service

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"regexp"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	"github.com/xebuonho/services/user-service/internal/model"
	"github.com/xebuonho/services/user-service/internal/repository"
	"github.com/xebuonho/services/user-service/internal/storage"
)

const (
	accessTokenTTL  = 15 * time.Minute
	refreshTokenTTL = 30 * 24 * time.Hour
	bcryptCost      = 12
	presignTTL      = 15 * time.Minute
)

// Upload whitelists for KYC documents (presigned PUT flow)
var allowedDocTypes = map[string]bool{
	"cccd_front": true, "cccd_back": true,
	"gplx_front": true, "gplx_back": true,
	"vehicle_registration": true, "vehicle_insurance": true,
	"business_license": true, "transport_license": true, "employment_contract": true,
}
var allowedContentTypes = map[string]string{
	"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp",
}
var idCardPattern = regexp.MustCompile(`^\d{12}$`)
var datePattern = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)

// AuthService handles authentication business logic
type AuthService struct {
	userRepo    *repository.UserRepository
	jwtSecret   string
	redisClient *redis.Client
	store       *storage.MinIOStore
	logger      *log.Logger
}

// NewAuthService creates a new auth service
func NewAuthService(userRepo *repository.UserRepository, jwtSecret string, redisClient *redis.Client, store *storage.MinIOStore) *AuthService {
	return &AuthService{
		userRepo:    userRepo,
		jwtSecret:   jwtSecret,
		redisClient: redisClient,
		store:       store,
		logger:      log.New(log.Writer(), "[auth] ", log.LstdFlags),
	}
}

// Register creates a new user account
func (s *AuthService) Register(ctx context.Context, req *model.RegisterRequest) (*model.TokenResponse, error) {
	// Validate compliance consent (Nghị định 13/2023/NĐ-CP)
	if !req.ConsentAccepted {
		return nil, fmt.Errorf("consent_required: bạn phải đồng ý với Điều khoản dịch vụ và Chính sách bảo vệ dữ liệu cá nhân (NĐ 13/2023/NĐ-CP)")
	}

	// Validate inputs
	if req.Phone == "" {
		return nil, fmt.Errorf("phone is required")
	}
	if req.Password == "" || len(req.Password) < 6 {
		return nil, fmt.Errorf("password must be at least 6 characters")
	}
	if req.FullName == "" {
		return nil, fmt.Errorf("full_name is required")
	}
	if req.Role == "" {
		req.Role = "rider"
	}
	if req.Role != "rider" && req.Role != "driver" && req.Role != "merchant" {
		return nil, fmt.Errorf("role must be rider, driver, or merchant")
	}

	// Check if user already exists
	existing, err := s.userRepo.GetByPhone(ctx, req.Phone)
	if err != nil {
		return nil, fmt.Errorf("check existing user: %w", err)
	}
	if existing != nil {
		return nil, fmt.Errorf("phone number already registered")
	}

	if req.Email != "" {
		existingEmail, err := s.userRepo.GetByEmail(ctx, req.Email)
		if err != nil {
			return nil, fmt.Errorf("check existing email: %w", err)
		}
		if existingEmail != nil {
			return nil, fmt.Errorf("email already registered")
		}
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcryptCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	consentVersion := req.ConsentVersion
	if consentVersion == "" {
		consentVersion = "2026.1"
	}
	now := time.Now()

	approvalStatus := "approved"
	if req.Role == "driver" {
		approvalStatus = "pending_approval"
	}

	driverKind := "personal"
	if req.Role == "driver" && req.DriverKind == "business" {
		driverKind = "business"
	}

	// Create user
	user := &model.User{
		Phone:          &req.Phone,
		FullName:       req.FullName,
		Role:           req.Role,
		PasswordHash:   string(hash),
		ConsentTermsAt: &now,
		ConsentVersion: consentVersion,
		ApprovalStatus: approvalStatus,
		DriverKind:     driverKind,
	}
	if req.Email != "" {
		user.Email = &req.Email
	}
	if req.VehicleType != "" {
		user.VehicleType = &req.VehicleType
	}
	if req.LicensePlate != "" {
		user.LicensePlate = &req.LicensePlate
	}
	if req.VehicleModel != "" {
		user.VehicleModel = &req.VehicleModel
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	s.logger.Printf("✅ User registered: %s [%s] %s (status: %s)", user.ID, user.Role, req.Phone, approvalStatus)

	// Generate tokens
	return s.generateTokenResponse(ctx, user)
}

// SubmitDriverKYC handles driver KYC documentation submission
func (s *AuthService) SubmitDriverKYC(ctx context.Context, driverID string, req *model.DriverKYCRequest) error {
	if req.IDCardNumber == "" {
		return fmt.Errorf("id_card_number is required")
	}
	if !idCardPattern.MatchString(req.IDCardNumber) {
		return fmt.Errorf("id_card_number phải gồm đúng 12 chữ số")
	}
	if req.DriverLicenseNumber == "" {
		return fmt.Errorf("driver_license_number is required")
	}
	if req.LicensePlate == "" {
		return fmt.Errorf("license_plate is required")
	}
	if req.VehicleType == "" {
		req.VehicleType = "car"
	}
	// If the request omits driver_kind, keep the kind on record so a business
	// driver can never be silently downgraded by submitting a personal form.
	if req.DriverKind == "" {
		existing, err := s.userRepo.GetByID(ctx, driverID)
		if err != nil {
			return fmt.Errorf("lookup driver: %w", err)
		}
		if existing == nil || existing.Role != "driver" {
			return fmt.Errorf("driver not found")
		}
		if existing.DriverKind == "business" {
			req.DriverKind = "business"
		} else {
			req.DriverKind = "personal"
		}
	}
	if req.DriverKind != "personal" && req.DriverKind != "business" {
		return fmt.Errorf("driver_kind must be personal or business")
	}
	if err := validateOptionalDate(req.DriverLicenseExpiry, "driver_license_expiry"); err != nil {
		return err
	}
	if err := validateOptionalDate(req.VehicleInsuranceExpiry, "vehicle_insurance_expiry"); err != nil {
		return err
	}

	// Business drivers (xe ô tô hợp đồng) must declare company + transport license per NĐ 10/2020 & 47/2022
	if req.DriverKind == "business" {
		if req.CompanyName == "" {
			return fmt.Errorf("company_name is required for business drivers")
		}
		if req.BusinessLicenseNumber == "" {
			return fmt.Errorf("business_license_number is required for business drivers")
		}
		if req.TransportLicenseNumber == "" {
			return fmt.Errorf("transport_license_number is required for business drivers")
		}
		if req.EmploymentContractURL == "" {
			return fmt.Errorf("employment_contract_url is required for business drivers")
		}
		if err := validateOptionalDate(req.TransportLicenseExpiry, "transport_license_expiry"); err != nil {
			return err
		}
	} else {
		// Personal drivers must not carry business paperwork
		req.CompanyName, req.BusinessLicenseNumber, req.TransportLicenseNumber = "", "", ""
		req.BusinessLicenseURL, req.TransportLicenseExpiry, req.EmploymentContractURL = "", "", ""
	}

	if err := s.userRepo.SubmitDriverKYC(ctx, driverID, req); err != nil {
		return err
	}
	s.publishDriverMeta(ctx, driverID, "pending_approval")
	return nil
}

// PresignUpload returns a presigned PUT URL for a KYC document upload
func (s *AuthService) PresignUpload(ctx context.Context, userID string, req *model.PresignUploadRequest) (*model.PresignUploadResponse, error) {
	if !allowedDocTypes[req.DocType] {
		return nil, fmt.Errorf("invalid doc_type %q", req.DocType)
	}
	expectedExt, ok := allowedContentTypes[req.ContentType]
	if !ok {
		return nil, fmt.Errorf("content_type must be image/jpeg, image/png or image/webp")
	}
	ext := strings.ToLower(strings.TrimPrefix(req.FileExt, "."))
	if ext != expectedExt {
		return nil, fmt.Errorf("file_ext %q does not match content_type %q", ext, req.ContentType)
	}

	objectKey := fmt.Sprintf("kyc/%s/%s/%d.%s", userID, req.DocType, time.Now().UnixNano(), ext)
	uploadURL, err := s.store.PresignPut(ctx, objectKey, presignTTL)
	if err != nil {
		return nil, fmt.Errorf("presign upload: %w", err)
	}
	return &model.PresignUploadResponse{
		ObjectKey: objectKey,
		UploadURL: uploadURL,
		ExpiresIn: int64(presignTTL.Seconds()),
	}, nil
}

// ListDriversForAdmin returns the driver moderation queue
func (s *AuthService) ListDriversForAdmin(ctx context.Context, status, driverKind string) ([]*model.AdminDriverListItem, error) {
	if status != "" && !isValidApprovalStatus(status) {
		return nil, fmt.Errorf("invalid status filter %q", status)
	}
	if driverKind != "" && driverKind != "personal" && driverKind != "business" {
		return nil, fmt.Errorf("invalid kind filter %q", driverKind)
	}
	return s.userRepo.ListDriversByStatus(ctx, status, driverKind, 100)
}

// GetDriverDetail returns a driver KYC profile with presigned document URLs
// (used by admin moderation and by the driver viewing their own submission)
func (s *AuthService) GetDriverDetail(ctx context.Context, driverID string) (*model.DriverKYCDetailResponse, error) {
	user, err := s.userRepo.GetByID(ctx, driverID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.Role != "driver" {
		return nil, fmt.Errorf("driver not found")
	}

	docURLs := map[string]string{}
	docFields := map[string]*string{
		"cccd_front":           user.IDCardFrontURL,
		"cccd_back":            user.IDCardBackURL,
		"gplx_front":           user.DriverLicenseFrontURL,
		"gplx_back":            user.DriverLicenseBackURL,
		"vehicle_registration": user.VehicleRegistrationURL,
		"vehicle_insurance":    user.VehicleInsuranceURL,
		"business_license":     user.BusinessLicenseURL,
		"transport_license":    user.TransportLicenseURL,
		"employment_contract":  user.EmploymentContractURL,
	}
	for name, key := range docFields {
		if key == nil || *key == "" {
			continue
		}
		url, err := s.store.PresignGet(ctx, *key, presignTTL)
		if err != nil {
			s.logger.Printf("⚠️ presign get failed for %s of driver %s: %v", name, driverID, err)
			continue
		}
		docURLs[name] = url
	}

	// Warn admins about expired/expiring documents instead of blocking approval
	warnings := []string{}
	now := time.Now()
	for _, w := range []struct {
		label string
		exp   *string
	}{
		{"Giấy phép lái xe đã hết hạn", user.DriverLicenseExpiry},
		{"Bảo hiểm TNDS đã hết hạn", user.VehicleInsuranceExpiry},
		{"Giấy phép vận tải đã hết hạn", user.TransportLicenseExpiry},
	} {
		if w.exp == nil || *w.exp == "" || !datePattern.MatchString(*w.exp) {
			continue
		}
		expTime, err := time.Parse("2006-01-02", *w.exp)
		if err == nil && expTime.Before(now) {
			warnings = append(warnings, w.label+" ("+*w.exp+")")
		}
	}

	return &model.DriverKYCDetailResponse{User: user, DocURLs: docURLs, Warnings: warnings}, nil
}

// UpdateDriverApprovalStatus handles admin review of driver application
func (s *AuthService) UpdateDriverApprovalStatus(ctx context.Context, driverID, status, reason string) error {
	if !isValidApprovalStatus(status) {
		return fmt.Errorf("invalid approval status %q", status)
	}
	if err := s.userRepo.UpdateDriverApprovalStatus(ctx, driverID, status, reason, ""); err != nil {
		return err
	}
	s.publishDriverMeta(ctx, driverID, status)
	s.logger.Printf("🛡 Driver %s approval status changed to %s", driverID, status)
	return nil
}

// UpdateDriverApprovalStatusBy records the admin actor for audit (NĐ 10/2020 traceability)
func (s *AuthService) UpdateDriverApprovalStatusBy(ctx context.Context, driverID, status, reason, adminID string) error {
	if !isValidApprovalStatus(status) {
		return fmt.Errorf("invalid approval status %q", status)
	}
	if err := s.userRepo.UpdateDriverApprovalStatus(ctx, driverID, status, reason, adminID); err != nil {
		return err
	}
	s.publishDriverMeta(ctx, driverID, status)
	s.logger.Printf("🛡 Driver %s approval status changed to %s by admin %s", driverID, status, adminID)
	return nil
}

func isValidApprovalStatus(status string) bool {
	switch status {
	case "unverified", "pending_approval", "approved", "rejected", "suspended":
		return true
	}
	return false
}

// publishDriverMeta mirrors approval_status into Redis so matching-service
// never proposes unapproved drivers (best-effort, demo data stays compatible).
func (s *AuthService) publishDriverMeta(ctx context.Context, driverID, status string) {
	if s.redisClient == nil {
		return
	}
	key := fmt.Sprintf("driver:%s:meta", driverID)
	if err := s.redisClient.HSet(ctx, key, "approval_status", status).Err(); err != nil {
		s.logger.Printf("⚠️ publish driver meta failed for %s: %v", driverID, err)
	}
}

func validateOptionalDate(value, field string) error {
	if value == "" {
		return nil
	}
	if !datePattern.MatchString(value) {
		return fmt.Errorf("%s must be YYYY-MM-DD", field)
	}
	if _, err := time.Parse("2006-01-02", value); err != nil {
		return fmt.Errorf("%s is not a valid date: %w", field, err)
	}
	return nil
}

// Login authenticates a user
func (s *AuthService) Login(ctx context.Context, req *model.LoginRequest) (*model.TokenResponse, error) {
	if req.Password == "" {
		return nil, fmt.Errorf("password is required")
	}

	var user *model.User
	var err error

	if req.Phone != "" {
		user, err = s.userRepo.GetByPhone(ctx, req.Phone)
	} else if req.Email != "" {
		user, err = s.userRepo.GetByEmail(ctx, req.Email)
	} else {
		return nil, fmt.Errorf("phone or email is required")
	}

	if err != nil {
		return nil, fmt.Errorf("find user: %w", err)
	}
	if user == nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}

	s.logger.Printf("✅ User logged in: %s [%s]", user.ID, user.Role)

	return s.generateTokenResponse(ctx, user)
}

// RefreshToken generates a new access token from a refresh token
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*model.TokenResponse, error) {
	if refreshToken == "" {
		return nil, fmt.Errorf("refresh_token is required")
	}

	user, err := s.userRepo.GetByRefreshToken(ctx, refreshToken)
	if err != nil {
		return nil, fmt.Errorf("lookup refresh token: %w", err)
	}
	if user == nil {
		return nil, fmt.Errorf("invalid or expired refresh token")
	}

	s.logger.Printf("🔄 Token refreshed: %s", user.ID)

	return s.generateTokenResponse(ctx, user)
}

// GetProfile retrieves user profile
func (s *AuthService) GetProfile(ctx context.Context, userID string) (*model.User, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, fmt.Errorf("user not found")
	}
	return user, nil
}

// UpdateProfile updates user profile
func (s *AuthService) UpdateProfile(ctx context.Context, userID string, req *model.UpdateProfileRequest) (*model.User, error) {
	if err := s.userRepo.UpdateProfile(ctx, userID, req); err != nil {
		return nil, fmt.Errorf("update profile: %w", err)
	}
	return s.GetProfile(ctx, userID)
}

// Logout clears the refresh token
func (s *AuthService) Logout(ctx context.Context, userID string) error {
	return s.userRepo.ClearRefreshToken(ctx, userID)
}

// generateTokenResponse creates access + refresh tokens
func (s *AuthService) generateTokenResponse(ctx context.Context, user *model.User) (*model.TokenResponse, error) {
	now := time.Now()

	// Access token (JWT)
	accessToken, err := s.signJWT(user.ID, user.Role, now, accessTokenTTL)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}

	// Refresh token (opaque random string)
	refreshToken, err := generateRandomToken(64)
	if err != nil {
		return nil, fmt.Errorf("generate refresh token: %w", err)
	}

	// Store refresh token
	if err := s.userRepo.UpdateRefreshToken(ctx, user.ID, refreshToken); err != nil {
		return nil, fmt.Errorf("store refresh token: %w", err)
	}

	return &model.TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    int64(accessTokenTTL.Seconds()),
		User:         user,
	}, nil
}

// signJWT creates a HMAC-SHA256 signed JWT
func (s *AuthService) signJWT(userID, role string, now time.Time, ttl time.Duration) (string, error) {
	// Header
	header := map[string]string{"alg": "HS256", "typ": "JWT"}
	headerJSON, _ := json.Marshal(header)
	headerB64 := base64.RawURLEncoding.EncodeToString(headerJSON)

	// Payload
	payload := map[string]interface{}{
		"user_id": userID,
		"role":    role,
		"iat":     now.Unix(),
		"exp":     now.Add(ttl).Unix(),
	}
	payloadJSON, _ := json.Marshal(payload)
	payloadB64 := base64.RawURLEncoding.EncodeToString(payloadJSON)

	// Signature
	signingInput := headerB64 + "." + payloadB64
	mac := hmac.New(sha256.New, []byte(s.jwtSecret))
	mac.Write([]byte(signingInput))
	signature := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))

	return signingInput + "." + signature, nil
}

// generateRandomToken generates a cryptographically random hex string
func generateRandomToken(length int) (string, error) {
	b := make([]byte, length)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// ValidateJWT validates a JWT and returns claims (used by middleware)
func (s *AuthService) ValidateJWT(tokenStr string) (userID, role string, err error) {
	parts := strings.Split(tokenStr, ".")
	if len(parts) != 3 {
		return "", "", fmt.Errorf("invalid token format")
	}

	// Verify signature
	signingInput := parts[0] + "." + parts[1]
	mac := hmac.New(sha256.New, []byte(s.jwtSecret))
	mac.Write([]byte(signingInput))
	expectedSig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(parts[2]), []byte(expectedSig)) {
		return "", "", fmt.Errorf("invalid signature")
	}

	// Decode payload
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return "", "", fmt.Errorf("invalid payload")
	}

	var claims struct {
		UserID string `json:"user_id"`
		Role   string `json:"role"`
		Exp    int64  `json:"exp"`
	}
	if err := json.Unmarshal(payload, &claims); err != nil {
		return "", "", fmt.Errorf("invalid claims")
	}

	if claims.Exp > 0 && time.Now().Unix() > claims.Exp {
		return "", "", fmt.Errorf("token expired")
	}

	return claims.UserID, claims.Role, nil
}
