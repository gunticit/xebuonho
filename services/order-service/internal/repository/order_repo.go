package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xebuonho/services/order-service/internal/model"
)

// OrderRepository handles order database operations
type OrderRepository struct {
	db *pgxpool.Pool
}

// NewOrderRepository creates a new order repository
func NewOrderRepository(db *pgxpool.Pool) *OrderRepository {
	return &OrderRepository{db: db}
}

// Create inserts a new order with idempotency check
func (r *OrderRepository) Create(ctx context.Context, order *model.Order) error {
	query := `
		INSERT INTO orders (
			idempotency_key, service_type, customer_id, merchant_id,
			pickup_location, pickup_address, dropoff_location, dropoff_address,
			vehicle_type, status, items_total, delivery_fee, service_fee,
			surge_multiplier, discount_amount, fare_estimate,
			promo_code, payment_method, distance_km, duration_minutes, metadata
		) VALUES (
			$1, $2, $3, $4,
			ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography, $7,
			ST_SetSRID(ST_MakePoint($8, $9), 4326)::geography, $10,
			$11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23
		)
		RETURNING id, created_at, updated_at
	`

	return r.db.QueryRow(ctx, query,
		order.IdempotencyKey, order.ServiceType, order.CustomerID, order.MerchantID,
		order.PickupLng, order.PickupLat, order.PickupAddress,
		order.DropoffLng, order.DropoffLat, order.DropoffAddress,
		order.VehicleType, order.Status, order.ItemsTotal, order.DeliveryFee,
		order.ServiceFee, order.SurgeMultiplier, order.DiscountAmount, order.FareEstimate,
		order.PromoCode, order.PaymentMethod, order.DistanceKm, order.DurationMinutes,
		order.Metadata,
	).Scan(&order.ID, &order.CreatedAt, &order.UpdatedAt)
}

// GetByID retrieves an order by ID
func (r *OrderRepository) GetByID(ctx context.Context, id string) (*model.Order, error) {
	query := `
		SELECT id, idempotency_key, service_type, customer_id, driver_id, merchant_id, shadow_driver_id,
			ST_Y(pickup_location::geometry) as pickup_lat, ST_X(pickup_location::geometry) as pickup_lng,
			pickup_address,
			ST_Y(dropoff_location::geometry) as dropoff_lat, ST_X(dropoff_location::geometry) as dropoff_lng,
			dropoff_address,
			vehicle_type, status, items_total, delivery_fee, service_fee,
			surge_multiplier, discount_amount, fare_estimate, fare_final,
			promo_code, payment_method, distance_km, duration_minutes,
			created_at, accepted_at, picked_up_at, delivered_at, completed_at,
			cancelled_at, cancelled_by, cancel_reason, metadata::text, updated_at
		FROM orders WHERE id = $1
	`

	o := &model.Order{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&o.ID, &o.IdempotencyKey, &o.ServiceType, &o.CustomerID,
		&o.DriverID, &o.MerchantID, &o.ShadowDriverID,
		&o.PickupLat, &o.PickupLng, &o.PickupAddress,
		&o.DropoffLat, &o.DropoffLng, &o.DropoffAddress,
		&o.VehicleType, &o.Status, &o.ItemsTotal, &o.DeliveryFee,
		&o.ServiceFee, &o.SurgeMultiplier, &o.DiscountAmount,
		&o.FareEstimate, &o.FareFinal,
		&o.PromoCode, &o.PaymentMethod, &o.DistanceKm, &o.DurationMinutes,
		&o.CreatedAt, &o.AcceptedAt, &o.PickedUpAt, &o.DeliveredAt,
		&o.CompletedAt, &o.CancelledAt, &o.CancelledBy, &o.CancelReason,
		&o.Metadata, &o.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("order not found: %s", id)
		}
		return nil, fmt.Errorf("get order: %w", err)
	}
	return o, nil
}

// GetByIdempotencyKey checks for existing order (dedup)
func (r *OrderRepository) GetByIdempotencyKey(ctx context.Context, key string) (*model.Order, error) {
	query := `SELECT id FROM orders WHERE idempotency_key = $1`
	var id string
	err := r.db.QueryRow(ctx, query, key).Scan(&id)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil // Not found = OK to create
		}
		return nil, err
	}
	return r.GetByID(ctx, id)
}

// UpdateStatus updates the order status and related timestamps
func (r *OrderRepository) UpdateStatus(ctx context.Context, id, status string) error {
	query := `UPDATE orders SET status = $2, updated_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id, status)
	return err
}

// AssignDriver assigns a driver to an order
func (r *OrderRepository) AssignDriver(ctx context.Context, orderID, driverID string) error {
	query := `UPDATE orders SET driver_id = $2, accepted_at = NOW(), updated_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, orderID, driverID)
	return err
}

// CancelOrder cancels an order
func (r *OrderRepository) CancelOrder(ctx context.Context, id, cancelledBy, reason string) error {
	query := `
		UPDATE orders SET
			status = CASE WHEN $2 = 'customer' THEN 'cancelled_by_customer' ELSE 'cancelled_by_driver' END,
			cancelled_at = NOW(), cancelled_by = $2, cancel_reason = $3, updated_at = NOW()
		WHERE id = $1
	`
	_, err := r.db.Exec(ctx, query, id, cancelledBy, reason)
	return err
}

// UpdateFareFinal sets the final fare after completion
func (r *OrderRepository) UpdateFareFinal(ctx context.Context, id string, fareFinal float64) error {
	query := `UPDATE orders SET fare_final = $2, updated_at = NOW() WHERE id = $1`
	_, err := r.db.Exec(ctx, query, id, fareFinal)
	return err
}

// ListByCustomer lists orders for a customer with pagination
func (r *OrderRepository) ListByCustomer(ctx context.Context, customerID, serviceType string, limit, offset int) ([]model.Order, int, error) {
	return r.listOrders(ctx, "customer_id", customerID, serviceType, limit, offset)
}

// ListByDriver lists orders for a driver with pagination
func (r *OrderRepository) ListByDriver(ctx context.Context, driverID, serviceType string, limit, offset int) ([]model.Order, int, error) {
	return r.listOrders(ctx, "driver_id", driverID, serviceType, limit, offset)
}

func (r *OrderRepository) listOrders(ctx context.Context, field, value, serviceType string, limit, offset int) ([]model.Order, int, error) {
	baseWhere := fmt.Sprintf("%s = $1", field)
	args := []interface{}{value}

	if serviceType != "" {
		args = append(args, serviceType)
		baseWhere += fmt.Sprintf(" AND service_type = $%d", len(args))
	}

	// Count
	var total int
	countQ := fmt.Sprintf("SELECT COUNT(*) FROM orders WHERE %s", baseWhere)
	if err := r.db.QueryRow(ctx, countQ, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	// Query
	selectQ := fmt.Sprintf(`
		SELECT id, idempotency_key, service_type, customer_id, driver_id, merchant_id,
			status, items_total, delivery_fee, service_fee, fare_estimate, fare_final,
			payment_method, distance_km, duration_minutes,
			created_at, accepted_at, completed_at, cancelled_at, updated_at
		FROM orders WHERE %s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d`, baseWhere, len(args)+1, len(args)+2)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, selectQ, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var orders []model.Order
	for rows.Next() {
		o := model.Order{}
		if err := rows.Scan(
			&o.ID, &o.IdempotencyKey, &o.ServiceType, &o.CustomerID, &o.DriverID,
			&o.MerchantID, &o.Status, &o.ItemsTotal, &o.DeliveryFee, &o.ServiceFee,
			&o.FareEstimate, &o.FareFinal, &o.PaymentMethod, &o.DistanceKm,
			&o.DurationMinutes, &o.CreatedAt, &o.AcceptedAt, &o.CompletedAt,
			&o.CancelledAt, &o.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		orders = append(orders, o)
	}
	return orders, total, nil
}
