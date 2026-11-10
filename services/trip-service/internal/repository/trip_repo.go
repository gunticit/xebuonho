package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xebuonho/services/trip-service/internal/model"
)

// terminalStatusSQL lists order statuses that count as finished trips.
const terminalStatusSQL = "('completed','paid','delivered','cancelled','cancelled_by_customer','cancelled_by_driver','merchant_rejected')"

// rateableStatusSQL lists statuses a customer may rate (a cancelled trip is not rateable).
const rateableStatusSQL = "('completed','paid','delivered')"

// tripColumns is the shared SELECT list for trip queries.
// $1 is always the requesting user id (used to attach their rating view).
const tripColumns = `o.id, o.service_type, o.status, o.customer_id, o.driver_id,
	COALESCE(du.full_name, ''),
	COALESCE(NULLIF(TRIM(COALESCE(du.license_plate, '') || ' · ' || COALESCE(du.vehicle_model, '')), ' · '), COALESCE(du.vehicle_model, du.license_plate, '')),
	o.pickup_address, o.dropoff_address, COALESCE(o.vehicle_type, ''),
	o.fare_estimate, o.fare_final, o.distance_km, o.duration_minutes,
	COALESCE(o.payment_method, 'cash'), COALESCE(o.cancelled_by, ''),
	o.created_at, o.completed_at,
	tr.rating, tr.tip_amount, tr.comment`

const tripJoins = `FROM orders o
	LEFT JOIN users du ON du.id = o.driver_id
	LEFT JOIN trip_ratings tr ON tr.order_id = o.id AND tr.rated_role = 'rider'`

type TripRepository struct {
	db *pgxpool.Pool
}

func NewTripRepository(db *pgxpool.Pool) *TripRepository {
	return &TripRepository{db: db}
}

// ListTrips returns finished trips for a user (role "rider" → customer, "driver" → driver).
func (r *TripRepository) ListTrips(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]model.Trip, int, error) {
	ownerCol := "customer_id"
	if role == "driver" {
		ownerCol = "driver_id"
	}

	where := fmt.Sprintf("o.%s = $1 AND o.status IN %s", ownerCol, terminalStatusSQL)
	args := []any{userID}
	if serviceType != "" {
		args = append(args, serviceType)
		where += fmt.Sprintf(" AND o.service_type = $%d", len(args))
	}

	var total int
	countSQL := "SELECT COUNT(*) FROM orders o WHERE " + where
	if err := r.db.QueryRow(ctx, countSQL, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count trips: %w", err)
	}

	offset := (page - 1) * pageSize
	listSQL := "SELECT " + tripColumns + " " + tripJoins + " WHERE " + where +
		fmt.Sprintf(" ORDER BY o.created_at DESC LIMIT $%d OFFSET $%d", len(args)+1, len(args)+2)
	args = append(args, pageSize, offset)

	rows, err := r.db.Query(ctx, listSQL, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list trips: %w", err)
	}
	defer rows.Close()

	trips, err := scanTrips(rows)
	if err != nil {
		return nil, 0, err
	}
	return trips, total, nil
}

// GetTrip returns one trip; the user must be a participant (customer or driver).
func (r *TripRepository) GetTrip(ctx context.Context, tripID, userID string) (*model.Trip, error) {
	sql := "SELECT " + tripColumns + " " + tripJoins +
		" WHERE o.id = $1 AND (o.customer_id = $2 OR o.driver_id = $2)"

	rows, err := r.db.Query(ctx, sql, tripID, userID)
	if err != nil {
		return nil, fmt.Errorf("get trip: %w", err)
	}
	defer rows.Close()

	trips, err := scanTrips(rows)
	if err != nil {
		return nil, err
	}
	if len(trips) == 0 {
		return nil, pgx.ErrNoRows
	}
	return &trips[0], nil
}

// GetOrderParticipants returns customer, driver and status of an order (for rating validation).
func (r *TripRepository) GetOrderParticipants(ctx context.Context, orderID string) (customerID, driverID, status string, err error) {
	sql := `SELECT customer_id, COALESCE(driver_id::text, ''), status FROM orders WHERE id = $1`
	if err = r.db.QueryRow(ctx, sql, orderID).Scan(&customerID, &driverID, &status); err != nil {
		if err == pgx.ErrNoRows {
			return "", "", "", pgx.ErrNoRows
		}
		return "", "", "", fmt.Errorf("get order participants: %w", err)
	}
	return customerID, driverID, status, nil
}

// UpsertRating inserts or updates the rater's rating for an order.
func (r *TripRepository) UpsertRating(ctx context.Context, orderID, customerID, driverID, ratedBy, ratedRole string, rating int, tipAmount float64, comment string) error {
	sql := `INSERT INTO trip_ratings (order_id, customer_id, driver_id, rated_by, rated_role, rating, tip_amount, comment)
		VALUES ($1, NULLIF($2,'')::uuid, NULLIF($3,'')::uuid, $4, $5, $6, $7, NULLIF($8,''))
		ON CONFLICT (order_id, rated_by) DO UPDATE
		SET rating = EXCLUDED.rating,
			tip_amount = EXCLUDED.tip_amount,
			comment = EXCLUDED.comment`

	if _, err := r.db.Exec(ctx, sql, orderID, customerID, driverID, ratedBy, ratedRole, rating, tipAmount, comment); err != nil {
		return fmt.Errorf("upsert rating: %w", err)
	}
	return nil
}

// GetRatingSummary aggregates customer ratings for a driver.
func (r *TripRepository) GetRatingSummary(ctx context.Context, driverID string) (*model.RatingSummary, error) {
	sql := `SELECT COALESCE(AVG(rating), 0), COUNT(*), COALESCE(SUM(tip_amount), 0)
		FROM trip_ratings WHERE driver_id = NULLIF($1,'')::uuid AND rated_role = 'rider'`

	var s model.RatingSummary
	if err := r.db.QueryRow(ctx, sql, driverID).Scan(&s.AverageRating, &s.TotalRatings, &s.TotalTips); err != nil {
		return nil, fmt.Errorf("get rating summary: %w", err)
	}
	s.DriverID = driverID
	return &s, nil
}

func scanTrips(rows pgx.Rows) ([]model.Trip, error) {
	var trips []model.Trip
	for rows.Next() {
		var t model.Trip
		if err := rows.Scan(
			&t.ID, &t.ServiceType, &t.Status, &t.CustomerID, &t.DriverID,
			&t.DriverName, &t.DriverVehicle,
			&t.PickupAddress, &t.DropoffAddress, &t.VehicleType,
			&t.FareEstimate, &t.FareFinal, &t.DistanceKm, &t.DurationMin,
			&t.PaymentMethod, &t.CancelledBy,
			&t.CreatedAt, &t.CompletedAt,
			&t.Rating, &t.TipAmount, &t.Comment,
		); err != nil {
			return nil, fmt.Errorf("scan trip: %w", err)
		}
		trips = append(trips, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate trips: %w", err)
	}
	return trips, nil
}
