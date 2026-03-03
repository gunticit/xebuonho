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
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"github.com/xebuonho/services/user-service/internal/model"
	"github.com/xebuonho/services/user-service/internal/repository"
)

const (
	accessTokenTTL  = 15 * time.Minute
	refreshTokenTTL = 30 * 24 * time.Hour
	bcryptCost      = 12
)

// AuthService handles authentication business logic
type AuthService struct {
	userRepo  *repository.UserRepository
	jwtSecret string
	logger    *log.Logger
}

// NewAuthService creates a new auth service
func NewAuthService(userRepo *repository.UserRepository, jwtSecret string) *AuthService {
	return &AuthService{
		userRepo:  userRepo,
		jwtSecret: jwtSecret,
		logger:    log.New(log.Writer(), "[auth] ", log.LstdFlags),
	}
}

// Register creates a new user account
func (s *AuthService) Register(ctx context.Context, req *model.RegisterRequest) (*model.TokenResponse, error) {
	// Validate
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

	// Create user
	user := &model.User{
		Phone:        &req.Phone,
		FullName:     req.FullName,
		Role:         req.Role,
		PasswordHash: string(hash),
	}
	if req.Email != "" {
		user.Email = &req.Email
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}

	s.logger.Printf("✅ User registered: %s [%s] %s", user.ID, user.Role, req.Phone)

	// Generate tokens
	return s.generateTokenResponse(ctx, user)
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
