package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xebuonho/services/user-service/internal/model"
)

// UserRepository handles user database operations
type UserRepository struct {
	db *pgxpool.Pool
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{db: db}
}

// Create inserts a new user
func (r *UserRepository) Create(ctx context.Context, user *model.User) error {
	query := `
		INSERT INTO users (
			phone, email, full_name, role, password_hash, is_verified, is_active,
			consent_terms_at, consent_version, approval_status, driver_kind,
			vehicle_type, license_plate, vehicle_model
		)
		VALUES (
			$1, $2, $3, $4, $5, FALSE, TRUE,
			$6, $7, $8, $9,
			$10, $11, $12
		)
		RETURNING id, created_at, updated_at
	`

	var phone, email *string
	if user.Phone != nil && *user.Phone != "" {
		phone = user.Phone
	}
	if user.Email != nil && *user.Email != "" {
		email = user.Email
	}

	approvalStatus := user.ApprovalStatus
	if approvalStatus == "" {
		if user.Role == "driver" {
			approvalStatus = "pending_approval"
		} else {
			approvalStatus = "approved"
		}
	}
	driverKind := user.DriverKind
	if driverKind == "" {
		driverKind = "personal"
	}

	return r.db.QueryRow(ctx, query,
		phone, email, user.FullName, user.Role, user.PasswordHash,
		user.ConsentTermsAt, user.ConsentVersion, approvalStatus, driverKind,
		user.VehicleType, user.LicensePlate, user.VehicleModel,
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)
}

// GetByPhone retrieves a user by phone number
func (r *UserRepository) GetByPhone(ctx context.Context, phone string) (*model.User, error) {
	return r.getByField(ctx, "phone", phone)
}

// GetByEmail retrieves a user by email
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	return r.getByField(ctx, "email", email)
}

// GetByID retrieves a user by ID
func (r *UserRepository) GetByID(ctx context.Context, id string) (*model.User, error) {
	return r.getByField(ctx, "id", id)
}

// GetByRefreshToken retrieves a user by refresh token
func (r *UserRepository) GetByRefreshToken(ctx context.Context, token string) (*model.User, error) {
	return r.getByField(ctx, "refresh_token", token)
}

func (r *UserRepository) getByField(ctx context.Context, field, value string) (*model.User, error) {
	query := fmt.Sprintf(`
		SELECT id, phone, email, full_name, avatar_url, role,
			is_verified, is_active, vehicle_type, license_plate, vehicle_model,
			driver_kind,
			consent_terms_at, consent_version,
			id_card_number, id_card_front_url, id_card_back_url,
			driver_license_number, driver_license_class, driver_license_expiry::text,
			driver_license_front_url, driver_license_back_url,
			vehicle_registration_url, vehicle_insurance_url, vehicle_insurance_expiry::text,
			company_name, company_tax_code,
			business_license_number, business_license_url,
			transport_license_number, transport_license_expiry::text, transport_license_url,
			employment_contract_url, blackbox_installed, cabin_camera_installed,
			approval_status, rejection_reason, approved_at, approved_by,
			password_hash, refresh_token, created_at, updated_at
		FROM users WHERE %s = $1 AND is_active = TRUE
	`, field)

	u := &model.User{}
	err := r.db.QueryRow(ctx, query, value).Scan(
		&u.ID, &u.Phone, &u.Email, &u.FullName, &u.AvatarURL, &u.Role,
		&u.IsVerified, &u.IsActive, &u.VehicleType, &u.LicensePlate, &u.VehicleModel,
		&u.DriverKind,
		&u.ConsentTermsAt, &u.ConsentVersion,
		&u.IDCardNumber, &u.IDCardFrontURL, &u.IDCardBackURL,
		&u.DriverLicenseNumber, &u.DriverLicenseClass, &u.DriverLicenseExpiry,
		&u.DriverLicenseFrontURL, &u.DriverLicenseBackURL,
		&u.VehicleRegistrationURL, &u.VehicleInsuranceURL, &u.VehicleInsuranceExpiry,
		&u.CompanyName, &u.CompanyTaxCode,
		&u.BusinessLicenseNumber, &u.BusinessLicenseURL,
		&u.TransportLicenseNumber, &u.TransportLicenseExpiry, &u.TransportLicenseURL,
		&u.EmploymentContractURL, &u.BlackboxInstalled, &u.CabinCameraInstalled,
		&u.ApprovalStatus, &u.RejectionReason, &u.ApprovedAt, &u.ApprovedBy,
		&u.PasswordHash, &u.RefreshToken, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("get user by %s: %w", field, err)
	}
	return u, nil
}

// SubmitDriverKYC updates driver verification documents and sets status to pending_approval
func (r *UserRepository) SubmitDriverKYC(ctx context.Context, driverID string, req *model.DriverKYCRequest) error {
	driverKind := req.DriverKind
	if driverKind == "" {
		driverKind = "personal"
	}
	query := `
		UPDATE users SET
			id_card_number = NULLIF($2, ''),
			id_card_front_url = NULLIF($3, ''),
			id_card_back_url = NULLIF($4, ''),
			driver_license_number = NULLIF($5, ''),
			driver_license_class = NULLIF($6, ''),
			driver_license_expiry = NULLIF($7, '')::date,
			driver_license_front_url = NULLIF($8, ''),
			driver_license_back_url = NULLIF($9, ''),
			vehicle_type = NULLIF($10, ''),
			license_plate = NULLIF($11, ''),
			vehicle_model = NULLIF($12, ''),
			vehicle_registration_url = NULLIF($13, ''),
			vehicle_insurance_url = NULLIF($14, ''),
			vehicle_insurance_expiry = NULLIF($15, '')::date,
			driver_kind = $16,
			company_name = NULLIF($17, ''),
			company_tax_code = NULLIF($18, ''),
			business_license_number = NULLIF($19, ''),
			business_license_url = NULLIF($20, ''),
			transport_license_number = NULLIF($21, ''),
			transport_license_expiry = NULLIF($22, '')::date,
			employment_contract_url = NULLIF($23, ''),
			blackbox_installed = $24,
			cabin_camera_installed = $25,
			transport_license_url = NULLIF($26, ''),
			approval_status = 'pending_approval',
			rejection_reason = NULL,
			updated_at = NOW()
		WHERE id = $1 AND role = 'driver'
	`
	tag, err := r.db.Exec(ctx, query,
		driverID,
		req.IDCardNumber, req.IDCardFrontURL, req.IDCardBackURL,
		req.DriverLicenseNumber, req.DriverLicenseClass, req.DriverLicenseExpiry,
		req.DriverLicenseFrontURL, req.DriverLicenseBackURL,
		req.VehicleType, req.LicensePlate, req.VehicleModel,
		req.VehicleRegistrationURL, req.VehicleInsuranceURL, req.VehicleInsuranceExpiry,
		driverKind,
		req.CompanyName, req.CompanyTaxCode, req.BusinessLicenseNumber, req.BusinessLicenseURL,
		req.TransportLicenseNumber, req.TransportLicenseExpiry, req.EmploymentContractURL,
		req.BlackboxInstalled, req.CabinCameraInstalled,
		req.TransportLicenseURL,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("driver not found or not driver role")
	}
	return nil
}

// UpdateDriverApprovalStatus changes driver status (approved, rejected, suspended)
func (r *UserRepository) UpdateDriverApprovalStatus(ctx context.Context, driverID, status, reason, approvedBy string) error {
	query := `
		UPDATE users SET
			approval_status = $2::varchar,
			rejection_reason = NULLIF($3, ''),
			approved_at = CASE WHEN $2::varchar = 'approved' THEN NOW() ELSE approved_at END,
			approved_by = CASE WHEN $2::varchar = 'approved' THEN NULLIF($4::text, '')::uuid ELSE approved_by END,
			updated_at = NOW()
		WHERE id = $1 AND role = 'driver'
	`
	tag, err := r.db.Exec(ctx, query, driverID, status, reason, approvedBy)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("driver not found or not driver role")
	}
	return nil
}

// ListDriversByStatus returns drivers filtered by approval status and kind for the admin panel
func (r *UserRepository) ListDriversByStatus(ctx context.Context, status, driverKind string, limit int) ([]*model.AdminDriverListItem, error) {
	query := `
		SELECT id, full_name, phone, email, driver_kind, approval_status,
			license_plate, vehicle_model, company_name, updated_at, rejection_reason
		FROM users
		WHERE role = 'driver' AND is_active = TRUE
			AND ($1 = '' OR approval_status = $1)
			AND ($2 = '' OR driver_kind = $2)
		ORDER BY updated_at DESC
		LIMIT $3
	`
	rows, err := r.db.Query(ctx, query, status, driverKind, limit)
	if err != nil {
		return nil, fmt.Errorf("list drivers: %w", err)
	}
	defer rows.Close()

	list := []*model.AdminDriverListItem{}
	for rows.Next() {
		item := &model.AdminDriverListItem{}
		if err := rows.Scan(
			&item.ID, &item.FullName, &item.Phone, &item.Email, &item.DriverKind, &item.ApprovalStatus,
			&item.LicensePlate, &item.VehicleModel, &item.Company, &item.SubmittedAt, &item.RejectionReason,
		); err != nil {
			return nil, fmt.Errorf("scan driver row: %w", err)
		}
		list = append(list, item)
	}
	return list, rows.Err()
}

// UpdateRefreshToken stores the refresh token for a user
func (r *UserRepository) UpdateRefreshToken(ctx context.Context, id, token string) error {
	query := `UPDATE users SET refresh_token = $2, updated_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id, token)
	return err
}

// ClearRefreshToken removes the refresh token (logout)
func (r *UserRepository) ClearRefreshToken(ctx context.Context, id string) error {
	query := `UPDATE users SET refresh_token = NULL, updated_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id)
	return err
}

// UpdatePassword updates the user's password hash
func (r *UserRepository) UpdatePassword(ctx context.Context, id, passwordHash string) error {
	query := `UPDATE users SET password_hash = $2, updated_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id, passwordHash)
	return err
}

// UpdateProfile updates user profile fields
func (r *UserRepository) UpdateProfile(ctx context.Context, id string, req *model.UpdateProfileRequest) error {
	query := `
		UPDATE users SET
			full_name = COALESCE(NULLIF($2, ''), full_name),
			email = COALESCE(NULLIF($3, ''), email),
			avatar_url = COALESCE(NULLIF($4, ''), avatar_url),
			vehicle_type = COALESCE(NULLIF($5, ''), vehicle_type),
			license_plate = COALESCE(NULLIF($6, ''), license_plate),
			vehicle_model = COALESCE(NULLIF($7, ''), vehicle_model),
			updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.db.Exec(ctx, query, id,
		req.FullName, req.Email, req.AvatarURL,
		req.VehicleType, req.LicensePlate, req.VehicleModel,
	)
	return err
}

// HasActiveOrders checks if user currently has active trips/orders
func (r *UserRepository) HasActiveOrders(ctx context.Context, userID string) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM orders
			WHERE (customer_id = $1 OR driver_id = $1)
			  AND status IN ('created', 'accepted', 'arrived', 'picking_up', 'in_trip', 'delivering', 'in_transit')
		)
	`
	var hasActive bool
	err := r.db.QueryRow(ctx, query, userID).Scan(&hasActive)
	if err != nil {
		if strings.Contains(err.Error(), "does not exist") {
			return false, nil
		}
		return false, err
	}
	return hasActive, nil
}

// DeleteAccount soft-deletes user account, clears PII & credentials, and frees up UNIQUE constraints
func (r *UserRepository) DeleteAccount(ctx context.Context, id string) error {
	query := `
		UPDATE users SET
			phone = NULL,
			email = NULL,
			full_name = 'Người dùng đã xóa',
			avatar_url = NULL,
			password_hash = NULL,
			refresh_token = NULL,
			is_active = FALSE,
			id_card_number = NULL,
			id_card_front_url = NULL,
			id_card_back_url = NULL,
			driver_license_number = NULL,
			driver_license_front_url = NULL,
			driver_license_back_url = NULL,
			vehicle_registration_url = NULL,
			vehicle_insurance_url = NULL,
			updated_at = NOW()
		WHERE id = $1
	`
	tag, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("user not found")
	}
	return nil
}
