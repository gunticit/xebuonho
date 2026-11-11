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

	// Driver kind: personal (xe cá nhân/xe máy) or business (xe ô tô hợp đồng doanh nghiệp)
	DriverKind string `json:"driver_kind,omitempty"`

	// Compliance PDPD (Nghị định 13/2023/NĐ-CP)
	ConsentTermsAt *time.Time `json:"consent_terms_at,omitempty"`
	ConsentVersion string     `json:"consent_version,omitempty"`

	// Driver KYC (Nghị định 10/2020/NĐ-CP)
	IDCardNumber           *string `json:"id_card_number,omitempty"`
	IDCardFrontURL         *string `json:"id_card_front_url,omitempty"`
	IDCardBackURL          *string `json:"id_card_back_url,omitempty"`
	DriverLicenseNumber    *string `json:"driver_license_number,omitempty"`
	DriverLicenseClass     *string `json:"driver_license_class,omitempty"`
	DriverLicenseExpiry    *string `json:"driver_license_expiry,omitempty"`
	DriverLicenseFrontURL  *string `json:"driver_license_front_url,omitempty"`
	DriverLicenseBackURL   *string `json:"driver_license_back_url,omitempty"`
	VehicleRegistrationURL *string `json:"vehicle_registration_url,omitempty"`
	VehicleInsuranceURL    *string `json:"vehicle_insurance_url,omitempty"`
	VehicleInsuranceExpiry *string `json:"vehicle_insurance_expiry,omitempty"`

	// Business driver documents (Nghị định 10/2020 + 47/2022/NĐ-CP)
	CompanyName            *string `json:"company_name,omitempty"`
	CompanyTaxCode         *string `json:"company_tax_code,omitempty"`
	BusinessLicenseNumber  *string `json:"business_license_number,omitempty"`
	BusinessLicenseURL     *string `json:"business_license_url,omitempty"`
	TransportLicenseNumber *string `json:"transport_license_number,omitempty"`
	TransportLicenseExpiry *string `json:"transport_license_expiry,omitempty"`
	TransportLicenseURL    *string `json:"transport_license_url,omitempty"`
	EmploymentContractURL  *string `json:"employment_contract_url,omitempty"`
	BlackboxInstalled      *bool   `json:"blackbox_installed,omitempty"`
	CabinCameraInstalled   *bool   `json:"cabin_camera_installed,omitempty"`

	// Driver Approval Status: unverified, pending_approval, approved, rejected, suspended
	ApprovalStatus  string  `json:"approval_status,omitempty"`
	RejectionReason *string `json:"rejection_reason,omitempty"`
	ApprovedAt      *time.Time `json:"approved_at,omitempty"`
	ApprovedBy      *string    `json:"approved_by,omitempty"`

	PasswordHash string    `json:"-"`
	RefreshToken *string   `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// RegisterRequest is the request payload for user registration
type RegisterRequest struct {
	Phone           string `json:"phone"`
	Email           string `json:"email,omitempty"`
	Password        string `json:"password"`
	FullName        string `json:"full_name"`
	Role            string `json:"role"` // rider, driver, merchant
	ConsentAccepted bool   `json:"consent_accepted"`
	ConsentVersion  string `json:"consent_version,omitempty"`

	// Driver kind when role == "driver": personal (default) or business
	DriverKind string `json:"driver_kind,omitempty"`

	// Optional initial vehicle info for driver
	VehicleType  string `json:"vehicle_type,omitempty"`
	LicensePlate string `json:"license_plate,omitempty"`
	VehicleModel string `json:"vehicle_model,omitempty"`
}

// DriverKYCRequest is the request payload for driver partner verification
type DriverKYCRequest struct {
	DriverKind             string `json:"driver_kind,omitempty"` // personal (default) or business
	IDCardNumber           string `json:"id_card_number"`
	IDCardFrontURL         string `json:"id_card_front_url,omitempty"`
	IDCardBackURL          string `json:"id_card_back_url,omitempty"`
	DriverLicenseNumber    string `json:"driver_license_number"`
	DriverLicenseClass     string `json:"driver_license_class"`
	DriverLicenseExpiry    string `json:"driver_license_expiry"`
	DriverLicenseFrontURL  string `json:"driver_license_front_url,omitempty"`
	DriverLicenseBackURL   string `json:"driver_license_back_url,omitempty"`
	VehicleType            string `json:"vehicle_type"`
	LicensePlate           string `json:"license_plate"`
	VehicleModel           string `json:"vehicle_model"`
	VehicleRegistrationURL string `json:"vehicle_registration_url,omitempty"`
	VehicleInsuranceURL    string `json:"vehicle_insurance_url,omitempty"`
	VehicleInsuranceExpiry string `json:"vehicle_insurance_expiry,omitempty"`

	// Business driver fields (required when DriverKind == "business")
	CompanyName            string `json:"company_name,omitempty"`
	CompanyTaxCode         string `json:"company_tax_code,omitempty"`
	BusinessLicenseNumber  string `json:"business_license_number,omitempty"`
	BusinessLicenseURL     string `json:"business_license_url,omitempty"`
	TransportLicenseNumber string `json:"transport_license_number,omitempty"`
	TransportLicenseExpiry string `json:"transport_license_expiry,omitempty"`
	TransportLicenseURL    string `json:"transport_license_url,omitempty"`
	EmploymentContractURL  string `json:"employment_contract_url,omitempty"`
	BlackboxInstalled      bool   `json:"blackbox_installed,omitempty"`
	CabinCameraInstalled   bool   `json:"cabin_camera_installed,omitempty"`
}

// PresignUploadRequest is the request for a presigned PUT URL
type PresignUploadRequest struct {
	DocType     string `json:"doc_type"`     // cccd_front, cccd_back, gplx_front, gplx_back, vehicle_registration, vehicle_insurance, business_license, transport_license, employment_contract
	FileExt     string `json:"file_ext"`     // jpg, png, webp
	ContentType string `json:"content_type"` // image/jpeg, image/png, image/webp
}

// PresignUploadResponse returns the object key + presigned PUT URL
type PresignUploadResponse struct {
	ObjectKey string `json:"object_key"`
	UploadURL string `json:"upload_url"`
	ExpiresIn int64  `json:"expires_in"`
}

// AdminDriverListItem is a row in the admin moderation list
type AdminDriverListItem struct {
	ID              string  `json:"id"`
	FullName        string  `json:"full_name"`
	Phone           *string `json:"phone,omitempty"`
	Email           *string `json:"email,omitempty"`
	DriverKind      string  `json:"driver_kind"`
	ApprovalStatus  string  `json:"approval_status"`
	LicensePlate    *string `json:"license_plate,omitempty"`
	VehicleModel    *string `json:"vehicle_model,omitempty"`
	Company         *string `json:"company_name,omitempty"`
	SubmittedAt     *time.Time `json:"submitted_at,omitempty"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
}

// AdminDriverDetailResponse wraps the full profile plus presigned document URLs
type AdminDriverDetailResponse struct {
	User       *User              `json:"user"`
	DocURLs    map[string]string  `json:"doc_urls"`
	Warnings   []string           `json:"warnings"`
}

// DriverApprovalRequest is the request payload for admin approving/rejecting driver
type DriverApprovalRequest struct {
	Status string `json:"status"` // approved, rejected, suspended
	Reason string `json:"reason,omitempty"`
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
