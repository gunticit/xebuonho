package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xebuonho/services/ride-service/internal/model"
)

// RideRepository handles ride database operations
type RideRepository struct {
	db *pgxpool.Pool
}

// NewRideRepository creates a new ride repository
func NewRideRepository(db *pgxpool.Pool) *RideRepository {
	return &RideRepository{db: db}
}

// Create inserts a new ride
func (r *RideRepository) Create(ctx context.Context, ride *model.Ride) error {
	query := `
		INSERT INTO orders (
			idempotency_key, service_type, customer_id,
			pickup_location, pickup_address, dropoff_location, dropoff_address,
			vehicle_type, status, fare_estimate, payment_method, promo_code,
			distance_km, duration_minutes
		) VALUES (
			$1, 'ride', $2,
			ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5,
			ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography, $8,
			$9, 'created', $10, $11, $12, $13, $14
		) RETURNING id, created_at, updated_at
	`

	return r.db.QueryRow(ctx, query,
		ride.IdempotencyKey, ride.RiderID,
		ride.PickupLng, ride.PickupLat, ride.PickupAddress,
		ride.DropoffLng, ride.DropoffLat, ride.DropoffAddress,
		ride.VehicleType, ride.FareEstimate, ride.PaymentMethod, ride.PromoCode,
		ride.DistanceKm, ride.DurationMin,
	).Scan(&ride.ID, &ride.CreatedAt, &ride.UpdatedAt)
}

// GetByID retrieves a ride by ID
func (r *RideRepository) GetByID(ctx context.Context, id string) (*model.Ride, error) {
	query := `
		SELECT id, idempotency_key, customer_id, driver_id,
			ST_Y(pickup_location::geometry), ST_X(pickup_location::geometry), pickup_address,
			ST_Y(dropoff_location::geometry), ST_X(dropoff_location::geometry), dropoff_address,
			vehicle_type, status, fare_estimate, fare_final, payment_method,
			distance_km, duration_minutes,
			created_at, accepted_at, picked_up_at, completed_at, cancelled_at, cancelled_by, updated_at
		FROM orders WHERE id = $1 AND service_type = 'ride'
	`

	ride := &model.Ride{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&ride.ID, &ride.IdempotencyKey, &ride.RiderID, &ride.DriverID,
		&ride.PickupLat, &ride.PickupLng, &ride.PickupAddress,
		&ride.DropoffLat, &ride.DropoffLng, &ride.DropoffAddress,
		&ride.VehicleType, &ride.Status, &ride.FareEstimate, &ride.FareFinal,
		&ride.PaymentMethod, &ride.DistanceKm, &ride.DurationMin,
		&ride.CreatedAt, &ride.AcceptedAt, &ride.PickedUpAt,
		&ride.CompletedAt, &ride.CancelledAt, &ride.CancelledBy, &ride.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("ride not found: %s", id)
		}
		return nil, fmt.Errorf("get ride: %w", err)
	}
	return ride, nil
}

// UpdateStatus updates ride status
func (r *RideRepository) UpdateStatus(ctx context.Context, id, status string) error {
	_, err := r.db.Exec(ctx, "UPDATE orders SET status = $2, updated_at = NOW() WHERE id = $1", id, status)
	return err
}

// ListByRider lists rides for a rider
func (r *RideRepository) ListByRider(ctx context.Context, riderID string, limit, offset int) ([]model.Ride, int, error) {
	var total int
	r.db.QueryRow(ctx,
		"SELECT COUNT(*) FROM orders WHERE customer_id = $1 AND service_type = 'ride'", riderID).Scan(&total)

	query := `
		SELECT id, customer_id, driver_id, vehicle_type, status,
			fare_estimate, fare_final, payment_method, distance_km, duration_minutes,
			created_at, completed_at, cancelled_at, updated_at
		FROM orders WHERE customer_id = $1 AND service_type = 'ride'
		ORDER BY created_at DESC LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(ctx, query, riderID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var rides []model.Ride
	for rows.Next() {
		ride := model.Ride{}
		rows.Scan(
			&ride.ID, &ride.RiderID, &ride.DriverID, &ride.VehicleType, &ride.Status,
			&ride.FareEstimate, &ride.FareFinal, &ride.PaymentMethod,
			&ride.DistanceKm, &ride.DurationMin,
			&ride.CreatedAt, &ride.CompletedAt, &ride.CancelledAt, &ride.UpdatedAt,
		)
		rides = append(rides, ride)
	}
	return rides, total, nil
}
