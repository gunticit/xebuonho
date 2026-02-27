package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xebuonho/services/merchant-service/internal/model"
)

// MerchantRepository handles merchant database operations
type MerchantRepository struct {
	db *pgxpool.Pool
}

// NewMerchantRepository creates a new merchant repository
func NewMerchantRepository(db *pgxpool.Pool) *MerchantRepository {
	return &MerchantRepository{db: db}
}

// Create inserts a new merchant
func (r *MerchantRepository) Create(ctx context.Context, input model.CreateMerchantInput) (*model.Merchant, error) {
	query := `
		INSERT INTO merchants (owner_id, name, description, category, phone, location, address, logo_url)
		VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography, $8, $9)
		RETURNING id, owner_id, name, description, category, phone,
			ST_Y(location::geometry) as latitude,
			ST_X(location::geometry) as longitude,
			address, logo_url, cover_url, rating, total_orders,
			is_active, is_verified, operating_hours::text, commission_rate,
			created_at, updated_at
	`

	m := &model.Merchant{}
	err := r.db.QueryRow(ctx, query,
		input.OwnerID, input.Name, input.Description, input.Category,
		input.Phone, input.Longitude, input.Latitude, input.Address, input.LogoURL,
	).Scan(
		&m.ID, &m.OwnerID, &m.Name, &m.Description, &m.Category, &m.Phone,
		&m.Latitude, &m.Longitude, &m.Address, &m.LogoURL, &m.CoverURL,
		&m.Rating, &m.TotalOrders, &m.IsActive, &m.IsVerified,
		&m.OperatingHours, &m.CommissionRate, &m.CreatedAt, &m.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create merchant: %w", err)
	}
	return m, nil
}

// GetByID retrieves a merchant by ID
func (r *MerchantRepository) GetByID(ctx context.Context, id string) (*model.Merchant, error) {
	query := `
		SELECT id, owner_id, name, description, category, phone,
			ST_Y(location::geometry) as latitude,
			ST_X(location::geometry) as longitude,
			address, logo_url, cover_url, rating, total_orders,
			is_active, is_verified, operating_hours::text, commission_rate,
			created_at, updated_at
		FROM merchants WHERE id = $1
	`

	m := &model.Merchant{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&m.ID, &m.OwnerID, &m.Name, &m.Description, &m.Category, &m.Phone,
		&m.Latitude, &m.Longitude, &m.Address, &m.LogoURL, &m.CoverURL,
		&m.Rating, &m.TotalOrders, &m.IsActive, &m.IsVerified,
		&m.OperatingHours, &m.CommissionRate, &m.CreatedAt, &m.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("merchant not found: %s", id)
		}
		return nil, fmt.Errorf("get merchant: %w", err)
	}
	return m, nil
}

// Update updates a merchant's details
func (r *MerchantRepository) Update(ctx context.Context, id string, name, description, phone, logoURL, operatingHours string, isActive bool) (*model.Merchant, error) {
	query := `
		UPDATE merchants SET
			name = COALESCE(NULLIF($2, ''), name),
			description = COALESCE(NULLIF($3, ''), description),
			phone = COALESCE(NULLIF($4, ''), phone),
			logo_url = COALESCE(NULLIF($5, ''), logo_url),
			operating_hours = CASE WHEN $6 = '' THEN operating_hours ELSE $6::jsonb END,
			is_active = $7,
			updated_at = NOW()
		WHERE id = $1
		RETURNING id, owner_id, name, description, category, phone,
			ST_Y(location::geometry) as latitude,
			ST_X(location::geometry) as longitude,
			address, logo_url, cover_url, rating, total_orders,
			is_active, is_verified, operating_hours::text, commission_rate,
			created_at, updated_at
	`

	m := &model.Merchant{}
	err := r.db.QueryRow(ctx, query, id, name, description, phone, logoURL, operatingHours, isActive).Scan(
		&m.ID, &m.OwnerID, &m.Name, &m.Description, &m.Category, &m.Phone,
		&m.Latitude, &m.Longitude, &m.Address, &m.LogoURL, &m.CoverURL,
		&m.Rating, &m.TotalOrders, &m.IsActive, &m.IsVerified,
		&m.OperatingHours, &m.CommissionRate, &m.CreatedAt, &m.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update merchant: %w", err)
	}
	return m, nil
}

// ListNearby finds merchants within a radius using PostGIS
func (r *MerchantRepository) ListNearby(ctx context.Context, lat, lng, radiusKm float64, category string, sortBy string, limit, offset int) ([]model.Merchant, int, error) {
	radiusMeters := radiusKm * 1000

	baseQuery := `
		FROM merchants
		WHERE is_active = true
			AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
	`
	args := []interface{}{lng, lat, radiusMeters}

	if category != "" {
		args = append(args, category)
		baseQuery += fmt.Sprintf(" AND category = $%d", len(args))
	}

	// Count total
	var total int
	countQuery := "SELECT COUNT(*) " + baseQuery
	if err := r.db.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count nearby: %w", err)
	}

	// Sort
	orderClause := " ORDER BY "
	switch sortBy {
	case "rating":
		orderClause += "rating DESC"
	case "popular":
		orderClause += "total_orders DESC"
	default:
		orderClause += fmt.Sprintf("ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)")
	}

	selectQuery := fmt.Sprintf(`
		SELECT id, owner_id, name, description, category, phone,
			ST_Y(location::geometry) as latitude,
			ST_X(location::geometry) as longitude,
			address, logo_url, cover_url, rating, total_orders,
			is_active, is_verified, operating_hours::text, commission_rate,
			created_at, updated_at,
			ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000.0 as distance_km
		%s %s LIMIT $%d OFFSET $%d`,
		baseQuery, orderClause, len(args)+1, len(args)+2)

	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, selectQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("query nearby: %w", err)
	}
	defer rows.Close()

	var merchants []model.Merchant
	for rows.Next() {
		m := model.Merchant{}
		if err := rows.Scan(
			&m.ID, &m.OwnerID, &m.Name, &m.Description, &m.Category, &m.Phone,
			&m.Latitude, &m.Longitude, &m.Address, &m.LogoURL, &m.CoverURL,
			&m.Rating, &m.TotalOrders, &m.IsActive, &m.IsVerified,
			&m.OperatingHours, &m.CommissionRate, &m.CreatedAt, &m.UpdatedAt,
			&m.DistanceKm,
		); err != nil {
			return nil, 0, fmt.Errorf("scan merchant: %w", err)
		}
		merchants = append(merchants, m)
	}

	return merchants, total, nil
}

// Search searches merchants by name or description
func (r *MerchantRepository) Search(ctx context.Context, query string, lat, lng, radiusKm float64, limit, offset int) ([]model.Merchant, int, error) {
	radiusMeters := radiusKm * 1000
	searchPattern := "%" + query + "%"

	baseQuery := `
		FROM merchants
		WHERE is_active = true
			AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
			AND (name ILIKE $4 OR description ILIKE $4)
	`

	var total int
	countQ := "SELECT COUNT(*) " + baseQuery
	if err := r.db.QueryRow(ctx, countQ, lng, lat, radiusMeters, searchPattern).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count search: %w", err)
	}

	selectQ := fmt.Sprintf(`
		SELECT id, owner_id, name, description, category, phone,
			ST_Y(location::geometry) as latitude, ST_X(location::geometry) as longitude,
			address, logo_url, cover_url, rating, total_orders,
			is_active, is_verified, operating_hours::text, commission_rate, created_at, updated_at,
			ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000.0 as distance_km
		%s ORDER BY rating DESC LIMIT $5 OFFSET $6`, baseQuery)

	rows, err := r.db.Query(ctx, selectQ, lng, lat, radiusMeters, searchPattern, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("search query: %w", err)
	}
	defer rows.Close()

	var merchants []model.Merchant
	for rows.Next() {
		m := model.Merchant{}
		if err := rows.Scan(
			&m.ID, &m.OwnerID, &m.Name, &m.Description, &m.Category, &m.Phone,
			&m.Latitude, &m.Longitude, &m.Address, &m.LogoURL, &m.CoverURL,
			&m.Rating, &m.TotalOrders, &m.IsActive, &m.IsVerified,
			&m.OperatingHours, &m.CommissionRate, &m.CreatedAt, &m.UpdatedAt,
			&m.DistanceKm,
		); err != nil {
			return nil, 0, fmt.Errorf("scan search: %w", err)
		}
		merchants = append(merchants, m)
	}

	return merchants, total, nil
}

// IncrementOrderCount increments the total_orders count
func (r *MerchantRepository) IncrementOrderCount(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		"UPDATE merchants SET total_orders = total_orders + 1, updated_at = NOW() WHERE id = $1", id)
	return err
}

// Suppress unused import warning
var _ = json.Marshal
