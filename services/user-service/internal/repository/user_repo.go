package repository

import (
	"context"
	"fmt"

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
		INSERT INTO users (phone, email, full_name, role, password_hash, is_verified, is_active)
		VALUES ($1, $2, $3, $4, $5, FALSE, TRUE)
		RETURNING id, created_at, updated_at
	`

	var phone, email *string
	if user.Phone != nil && *user.Phone != "" {
		phone = user.Phone
	}
	if user.Email != nil && *user.Email != "" {
		email = user.Email
	}

	return r.db.QueryRow(ctx, query,
		phone, email, user.FullName, user.Role, user.PasswordHash,
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
			password_hash, refresh_token, created_at, updated_at
		FROM users WHERE %s = $1 AND is_active = TRUE
	`, field)

	u := &model.User{}
	err := r.db.QueryRow(ctx, query, value).Scan(
		&u.ID, &u.Phone, &u.Email, &u.FullName, &u.AvatarURL, &u.Role,
		&u.IsVerified, &u.IsActive, &u.VehicleType, &u.LicensePlate, &u.VehicleModel,
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
