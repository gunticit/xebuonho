package model

import (
	"time"
)

// User represents a user in the system
type User struct {
	ID           string    `json:"id"`
	Phone        *string   `json:"phone,omitempty"`
	Email        *string   `json:"email,omitempty"`
	FullName     string    `json:"full_name"`
	AvatarURL    *string   `json:"avatar_url,omitempty"`
	Role         string    `json:"role"`
	IsVerified   bool      `json:"is_verified"`
	IsActive     bool      `json:"is_active"`
	VehicleType  *string   `json:"vehicle_type,omitempty"`
	LicensePlate *string   `json:"license_plate,omitempty"`
	VehicleModel *string   `json:"vehicle_model,omitempty"`
	PasswordHash string    `json:"-"`
	RefreshToken *string   `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// RegisterRequest is the request payload for user registration
type RegisterRequest struct {
	Phone    string `json:"phone"`
	Email    string `json:"email,omitempty"`
	Password string `json:"password"`
	FullName string `json:"full_name"`
	Role     string `json:"role"` // rider, driver, merchant
}

// LoginRequest is the request payload for login
type LoginRequest struct {
	Phone    string `json:"phone,omitempty"`
	Email    string `json:"email,omitempty"`
	Password string `json:"password"`
}

// RefreshRequest is the request for token refresh
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

// UpdateProfileRequest is the request for profile update
type UpdateProfileRequest struct {
	FullName     string `json:"full_name,omitempty"`
	Email        string `json:"email,omitempty"`
	AvatarURL    string `json:"avatar_url,omitempty"`
	VehicleType  string `json:"vehicle_type,omitempty"`
	LicensePlate string `json:"license_plate,omitempty"`
	VehicleModel string `json:"vehicle_model,omitempty"`
}

// TokenResponse is the response containing auth tokens
type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int64  `json:"expires_in"`
	User         *User  `json:"user"`
}

// ProfileResponse is the user profile response
type ProfileResponse struct {
	User *User `json:"user"`
}
