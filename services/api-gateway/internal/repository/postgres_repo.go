package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresRepo struct {
	db *pgxpool.Pool
}

func NewPostgresRepo(db *pgxpool.Pool) *PostgresRepo {
	return &PostgresRepo{db: db}
}

// ==========================================
// Ride & Orders Models & Methods
// ==========================================
type CreateRideParams struct {
	IdempotencyKey string
	ServiceType    string
	RiderID        string
	PickupLat      float64
	PickupLng      float64
	PickupAddress  string
	DropoffLat     float64
	DropoffLng     float64
	DropoffAddress string
	VehicleType    string
	PaymentMethod  string
	PromoCode      string
	FareEstimate   float64
	DistanceKm     float64
	DurationMin    int
	Notes          string
	// Designated driver (lái xe hộ) — columns from migration 000003
	DesignatedMode         string
	DesignatedVehicleType  string
	DesignatedLicensePlate string
	// Scheduled ride: future time → order starts in status 'scheduled' and a
	// gateway worker flips it to 'created' when due.
	ScheduledAt *time.Time
}

type DriverInfo struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Phone        string   `json:"phone,omitempty"`
	VehicleModel string   `json:"vehicle_model,omitempty"`
	Plate        string   `json:"license_plate,omitempty"`
	Rating       *float64 `json:"rating,omitempty"`
	// Realtime position from the in-memory per-driver location store (may be nil)
	Lat *float64 `json:"lat,omitempty"`
	Lng *float64 `json:"lng,omitempty"`
}

type RideResult struct {
	ID             string    `json:"id"`
	ServiceType    string    `json:"service_type"`
	RiderID        string    `json:"rider_id"`
	PickupLat      float64   `json:"pickup_lat,omitempty"`
	PickupLng      float64   `json:"pickup_lng,omitempty"`
	PickupAddress  string    `json:"pickup_address"`
	DropoffLat     float64   `json:"dropoff_lat,omitempty"`
	DropoffLng     float64   `json:"dropoff_lng,omitempty"`
	DropoffAddress string    `json:"dropoff_address"`
	VehicleType    string    `json:"vehicle_type"`
	Status         string    `json:"status"`
	FareEstimate   float64   `json:"fare_estimate"`
	FareFinal      *float64  `json:"fare_final,omitempty"`
	PaymentMethod  string    `json:"payment_method,omitempty"`
	Notes          string    `json:"notes,omitempty"`
	DistanceKm     float64   `json:"distance_km"`
	DurationMin    int       `json:"duration_minutes"`
	ScheduledAt    *time.Time `json:"scheduled_at,omitempty"`
	AcceptedAt     *time.Time `json:"accepted_at,omitempty"`
	CompletedAt    *time.Time `json:"completed_at,omitempty"`
	CancelledAt    *time.Time `json:"cancelled_at,omitempty"`
	CancelledBy    string     `json:"cancelled_by,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	CustomerName   string     `json:"customer_name,omitempty"`
	CustomerPhone  string     `json:"customer_phone,omitempty"`
	Driver         *DriverInfo `json:"driver,omitempty"`
}

func (r *PostgresRepo) CreateRide(ctx context.Context, p CreateRideParams) (*RideResult, error) {
	serviceType := p.ServiceType
	if serviceType == "" {
		serviceType = "ride"
	}
	status := "created"
	var scheduledAt *time.Time
	if p.ScheduledAt != nil && p.ScheduledAt.After(time.Now()) {
		status = "scheduled"
		scheduledAt = p.ScheduledAt
	}

	query := `
		INSERT INTO orders (
			idempotency_key, service_type, customer_id,
			pickup_location, pickup_address, dropoff_location, dropoff_address,
			vehicle_type, status, fare_estimate, payment_method, promo_code,
			distance_km, duration_minutes, metadata,
			designated_mode, designated_vehicle_type, designated_license_plate,
			scheduled_at
		) VALUES (
			$1, $2, $3,
			ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6,
			ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography, $9,
			$10, $11, $12, $13, $14, $15, $16, $17::jsonb,
			NULLIF($18, ''), NULLIF($19, ''), NULLIF($20, ''),
			$21
		)
		ON CONFLICT (idempotency_key) DO UPDATE SET updated_at = NOW()
		RETURNING id, service_type, customer_id,
		          ST_X(pickup_location::geometry), ST_Y(pickup_location::geometry),
		          ST_X(dropoff_location::geometry), ST_Y(dropoff_location::geometry),
		          pickup_address, dropoff_address, vehicle_type, status,
		          fare_estimate, COALESCE(distance_km, 0), COALESCE(duration_minutes, 0),
		          scheduled_at, created_at
	`

	res := &RideResult{}
	metadataJSON := "{}"
	if p.Notes != "" {
		if b, err := json.Marshal(map[string]string{"notes": p.Notes}); err == nil {
			metadataJSON = string(b)
		}
	}
	err := r.db.QueryRow(ctx, query,
		p.IdempotencyKey, serviceType, p.RiderID,
		p.PickupLng, p.PickupLat, p.PickupAddress,
		p.DropoffLng, p.DropoffLat, p.DropoffAddress,
		p.VehicleType, status, p.FareEstimate, p.PaymentMethod, p.PromoCode,
		p.DistanceKm, p.DurationMin, metadataJSON,
		p.DesignatedMode, p.DesignatedVehicleType, p.DesignatedLicensePlate,
		scheduledAt,
	).Scan(
		&res.ID, &res.ServiceType, &res.RiderID,
		&res.PickupLat, &res.PickupLng, &res.DropoffLat, &res.DropoffLng,
		&res.PickupAddress, &res.DropoffAddress, &res.VehicleType, &res.Status,
		&res.FareEstimate, &res.DistanceKm, &res.DurationMin,
		&res.ScheduledAt, &res.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("insert ride order: %w", err)
	}
	return res, nil
}

// CancelRideByUser cancels an order by its customer. Only the owner may cancel,
// and only while the order is still created or accepted (FSM guard).
func (r *PostgresRepo) CancelRideByUser(ctx context.Context, orderID, customerID, reason string) error {
	query := `
		UPDATE orders
		SET status = 'cancelled', cancelled_by = 'customer',
		    cancelled_at = NOW(), cancel_reason = NULLIF($3, ''), updated_at = NOW()
		WHERE id = $1 AND customer_id = $2 AND status IN ('created', 'accepted')
	`
	tag, err := r.db.Exec(ctx, query, orderID, customerID, reason)
	if err != nil {
		return fmt.Errorf("cancel ride: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("ride not found, already picked up/completed, or not yours to cancel")
	}
	return nil
}

// ListRideMessages returns the chat history of an order (participants only).
func (r *PostgresRepo) ListRideMessages(ctx context.Context, orderID, userID string, limit int) ([]map[string]interface{}, error) {
	// Participant guard: only rider or assigned driver of this order may read.
	var ok bool
	err := r.db.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM orders WHERE id = $1 AND (customer_id = $2 OR driver_id = $2))`,
		orderID, userID).Scan(&ok)
	if err != nil {
		return nil, fmt.Errorf("check participant: %w", err)
	}
	if !ok {
		return nil, fmt.Errorf("not a participant of this ride")
	}
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	rows, err := r.db.Query(ctx, `
		SELECT m.id, m.sender_id, m.sender_role, m.message, m.created_at, COALESCE(u.full_name, '')
		FROM order_messages m
		LEFT JOIN users u ON u.id = m.sender_id
		WHERE m.order_id = $1
		ORDER BY m.created_at ASC
		LIMIT $2
	`, orderID, limit)
	if err != nil {
		return nil, fmt.Errorf("list messages: %w", err)
	}
	defer rows.Close()

	list := []map[string]interface{}{}
	for rows.Next() {
		var id, senderID, senderRole, message, senderName string
		var createdAt time.Time
		if err := rows.Scan(&id, &senderID, &senderRole, &message, &createdAt, &senderName); err != nil {
			return nil, fmt.Errorf("scan message: %w", err)
		}
		list = append(list, map[string]interface{}{
			"id": id, "sender_id": senderID, "sender_role": senderRole,
			"message": message, "sender_name": senderName,
			"created_at": createdAt.Format(time.RFC3339),
		})
	}
	return list, rows.Err()
}

// AddRideMessage appends a chat message to an order (participants only).
func (r *PostgresRepo) AddRideMessage(ctx context.Context, orderID, senderID, senderRole, message string) (map[string]interface{}, error) {
	// Participant guard
	var ok bool
	err := r.db.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM orders WHERE id = $1 AND (customer_id = $2 OR driver_id = $2))`,
		orderID, senderID).Scan(&ok)
	if err != nil {
		return nil, fmt.Errorf("check participant: %w", err)
	}
	if !ok {
		return nil, fmt.Errorf("not a participant of this ride")
	}

	var id string
	var createdAt time.Time
	err = r.db.QueryRow(ctx, `
		INSERT INTO order_messages (order_id, sender_id, sender_role, message)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at
	`, orderID, senderID, senderRole, message).Scan(&id, &createdAt)
	if err != nil {
		return nil, fmt.Errorf("add message: %w", err)
	}
	return map[string]interface{}{
		"id": id, "order_id": orderID, "sender_id": senderID,
		"sender_role": senderRole, "message": message,
		"created_at": createdAt.Format(time.RFC3339),
	}, nil
}

// GetDriversByIDs returns lightweight driver profiles keyed by user id,
// used to enrich the realtime nearby-driver list.
func (r *PostgresRepo) GetDriversByIDs(ctx context.Context, ids []string) (map[string]map[string]interface{}, error) {
	out := map[string]map[string]interface{}{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, full_name, phone::text, COALESCE(vehicle_type, ''),
		       COALESCE(vehicle_model, ''), COALESCE(license_plate, '')
		FROM users WHERE id = ANY($1::uuid[]) AND role = 'driver'
	`, ids)
	if err != nil {
		return nil, fmt.Errorf("get drivers by ids: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var id, name, phone, vtype, vmodel, plate string
		if err := rows.Scan(&id, &name, &phone, &vtype, &vmodel, &plate); err != nil {
			return nil, err
		}
		out[id] = map[string]interface{}{
			"name": name, "phone": phone, "vehicle_type": vtype,
			"vehicle_model": vmodel, "license_plate": plate,
		}
	}
	return out, rows.Err()
}

// ActivateDueScheduledRides flips scheduled orders to 'created' once their time
// arrives, so they surface in the driver pending list. Returns rows affected.
func (r *PostgresRepo) ActivateDueScheduledRides(ctx context.Context) (int64, error) {
	tag, err := r.db.Exec(ctx, `
		UPDATE orders SET status = 'created', updated_at = NOW()
		WHERE status = 'scheduled' AND scheduled_at IS NOT NULL AND scheduled_at <= NOW()
	`)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// GetRide returns the full order state plus assigned driver/customer profiles.
// Driver rating is the AVG of trip_ratings rated by riders (null → client default).
func (r *PostgresRepo) GetRide(ctx context.Context, rideID string) (*RideResult, error) {
	query := `
		SELECT o.id, o.service_type, o.customer_id,
			ST_Y(o.pickup_location::geometry), ST_X(o.pickup_location::geometry),
			ST_Y(o.dropoff_location::geometry), ST_X(o.dropoff_location::geometry),
			o.pickup_address, o.dropoff_address, o.vehicle_type, o.status,
			o.fare_estimate, o.fare_final, COALESCE(o.payment_method, ''), COALESCE(o.metadata->>'notes', ''),
			COALESCE(o.distance_km, 0), COALESCE(o.duration_minutes, 0),
			o.scheduled_at, o.accepted_at, o.completed_at, o.cancelled_at, COALESCE(o.cancelled_by, ''),
			o.created_at,
			COALESCE(cu.full_name, ''), COALESCE(cu.phone::text, ''),
			d.id, COALESCE(d.full_name, ''), COALESCE(d.phone::text, ''),
			COALESCE(d.vehicle_model, ''), COALESCE(d.license_plate, ''),
			(SELECT ROUND(AVG(rating)::numeric, 2)::float8 FROM trip_ratings tr
			  WHERE tr.driver_id = d.id AND tr.rated_role = 'driver')
		FROM orders o
		LEFT JOIN users cu ON cu.id = o.customer_id
		LEFT JOIN users d ON d.id = o.driver_id
		WHERE o.id = $1
	`
	res := &RideResult{}
	var (
		fareFinal   *float64
		driverID    *string
		driverName  string
		driverPhone string
		drvModel    string
		drvPlate    string
		driverRate  *float64
	)
	err := r.db.QueryRow(ctx, query, rideID).Scan(
		&res.ID, &res.ServiceType, &res.RiderID,
		&res.PickupLat, &res.PickupLng, &res.DropoffLat, &res.DropoffLng,
		&res.PickupAddress, &res.DropoffAddress, &res.VehicleType, &res.Status,
		&res.FareEstimate, &fareFinal, &res.PaymentMethod, &res.Notes,
		&res.DistanceKm, &res.DurationMin,
		&res.ScheduledAt, &res.AcceptedAt, &res.CompletedAt, &res.CancelledAt, &res.CancelledBy,
		&res.CreatedAt,
		&res.CustomerName, &res.CustomerPhone,
		&driverID, &driverName, &driverPhone, &drvModel, &drvPlate, &driverRate,
	)
	if err != nil {
		return nil, fmt.Errorf("get ride: %w", err)
	}
	res.FareFinal = fareFinal
	if driverID != nil && *driverID != "" {
		res.Driver = &DriverInfo{
			ID:           *driverID,
			Name:         driverName,
			Phone:        driverPhone,
			VehicleModel: drvModel,
			Plate:        drvPlate,
			Rating:       driverRate,
		}
	}
	return res, nil
}

// ==========================================
// Merchants & Food Methods
// ==========================================
type MerchantItem struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Category    string  `json:"category"`
	Phone       string  `json:"phone"`
	Address     string  `json:"address"`
	LogoURL     string  `json:"logo_url"`
	CoverURL    string  `json:"cover_url"`
	Rating      float64 `json:"rating"`
	TotalOrders int     `json:"total_orders"`
	IsActive    bool    `json:"is_active"`
	DistanceKm  float64 `json:"distance_km"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
}

func (r *PostgresRepo) ListNearbyMerchants(ctx context.Context, lat, lng, radiusKm float64, category string) ([]MerchantItem, error) {
	radiusMeters := radiusKm * 1000
	if radiusMeters <= 0 {
		radiusMeters = 20000 // default 20km
	}

	query := `
		SELECT id, name, description, category, COALESCE(phone, ''),
		       ST_Y(location::geometry) as latitude,
		       ST_X(location::geometry) as longitude,
		       address, COALESCE(logo_url, ''), COALESCE(cover_url, ''),
		       rating, total_orders, is_active,
		       ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000.0 as distance_km
		FROM merchants
		WHERE is_active = true
		  AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
	`
	args := []interface{}{lng, lat, radiusMeters}
	if category != "" {
		query += " AND category = $4"
		args = append(args, category)
	}
	query += " ORDER BY distance_km ASC LIMIT 20"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("query merchants: %w", err)
	}
	defer rows.Close()

	var list []MerchantItem
	for rows.Next() {
		var m MerchantItem
		if err := rows.Scan(
			&m.ID, &m.Name, &m.Description, &m.Category, &m.Phone,
			&m.Latitude, &m.Longitude, &m.Address, &m.LogoURL, &m.CoverURL,
			&m.Rating, &m.TotalOrders, &m.IsActive, &m.DistanceKm,
		); err != nil {
			return nil, err
		}
		list = append(list, m)
	}
	return list, nil
}

type MenuItem struct {
	ID          string  `json:"id"`
	MerchantID  string  `json:"merchant_id"`
	Category    string  `json:"category_name"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
	ImageURL    string  `json:"image_url"`
	IsAvailable bool    `json:"is_available"`
}

func (r *PostgresRepo) GetMerchantMenu(ctx context.Context, merchantID string) ([]MenuItem, error) {
	query := `
		SELECT id, merchant_id, COALESCE(category_name, 'Món ngon'), name,
		       COALESCE(description, ''), price, COALESCE(image_url, ''), is_available
		FROM menu_items
		WHERE merchant_id = $1 AND is_available = true
		ORDER BY sort_order ASC, created_at ASC
	`
	rows, err := r.db.Query(ctx, query, merchantID)
	if err != nil {
		return nil, fmt.Errorf("query menu items: %w", err)
	}
	defer rows.Close()

	var items []MenuItem
	for rows.Next() {
		var it MenuItem
		if err := rows.Scan(
			&it.ID, &it.MerchantID, &it.Category, &it.Name,
			&it.Description, &it.Price, &it.ImageURL, &it.IsAvailable,
		); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, nil
}

// ==========================================
// Driver Real-Time Ride Matching Methods
// ==========================================
type PendingRide struct {
	ID             string    `json:"id"`
	ServiceType    string    `json:"service_type"`
	CustomerName   string    `json:"customer_name"`
	CustomerPhone  string    `json:"customer_phone"`
	PickupAddress  string    `json:"pickup_address"`
	PickupLat      float64   `json:"pickup_lat"`
	PickupLng      float64   `json:"pickup_lng"`
	DropoffAddress string    `json:"dropoff_address"`
	DropoffLat     float64   `json:"dropoff_lat"`
	DropoffLng     float64   `json:"dropoff_lng"`
	VehicleType    string    `json:"vehicle_type"`
	FareEstimate   float64   `json:"fare_estimate"`
	PaymentMethod  string    `json:"payment_method"`
	DistanceKm     float64   `json:"distance_km"`
	DurationMin    int       `json:"duration_min"`
	CreatedAt      time.Time `json:"created_at"`
}

func (r *PostgresRepo) ListPendingRides(ctx context.Context) ([]PendingRide, error) {
	query := `
		SELECT o.id, o.service_type, COALESCE(u.full_name, 'Khách hàng'), COALESCE(u.phone, ''),
		       o.pickup_address,
		       ST_Y(o.pickup_location::geometry) as pickup_lat,
		       ST_X(o.pickup_location::geometry) as pickup_lng,
		       o.dropoff_address,
		       ST_Y(o.dropoff_location::geometry) as dropoff_lat,
		       ST_X(o.dropoff_location::geometry) as dropoff_lng,
		       COALESCE(o.vehicle_type, 'car'), o.fare_estimate, o.payment_method,
		       COALESCE(o.distance_km, 3.5), COALESCE(o.duration_minutes, 10),
		       o.created_at
		FROM orders o
		LEFT JOIN users u ON o.customer_id = u.id
		WHERE o.status = 'created'
		ORDER BY o.created_at DESC
		LIMIT 10
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query pending rides: %w", err)
	}
	defer rows.Close()

	var list []PendingRide
	for rows.Next() {
		var p PendingRide
		if err := rows.Scan(
			&p.ID, &p.ServiceType, &p.CustomerName, &p.CustomerPhone,
			&p.PickupAddress, &p.PickupLat, &p.PickupLng,
			&p.DropoffAddress, &p.DropoffLat, &p.DropoffLng,
			&p.VehicleType, &p.FareEstimate, &p.PaymentMethod,
			&p.DistanceKm, &p.DurationMin, &p.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, p)
	}
	return list, nil
}

func (r *PostgresRepo) AcceptRide(ctx context.Context, orderID, driverID string) error {
	// The approval subquery makes the KYC gate atomic with the ride claim:
	// an unapproved/suspended driver can never win the race for a ride.
	query := `
		UPDATE orders
		SET driver_id = $2, status = 'accepted', accepted_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND status = 'created' AND customer_id != $2
			AND EXISTS (
				SELECT 1 FROM users u
				WHERE u.id = $2 AND u.role = 'driver'
					AND u.approval_status = 'approved' AND u.is_active = TRUE
			)
	`
	cmd, err := r.db.Exec(ctx, query, orderID, driverID)
	if err != nil {
		return fmt.Errorf("accept ride: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("ride already accepted, not found, driver cannot accept own ride, or driver not approved")
	}
	return nil
}

func (r *PostgresRepo) UpdateRideStatus(ctx context.Context, orderID, driverID, status string) error {
	var query string
	var args []interface{}
	if status == "completed" {
		if driverID != "" {
			query = `
				UPDATE orders
				SET status = $2, completed_at = NOW(), fare_final = COALESCE(fare_final, fare_estimate), updated_at = NOW()
				WHERE id = $1 AND (driver_id = $3 OR driver_id IS NULL)
			`
			args = []interface{}{orderID, status, driverID}
		} else {
			query = `
				UPDATE orders
				SET status = $2, completed_at = NOW(), fare_final = COALESCE(fare_final, fare_estimate), updated_at = NOW()
				WHERE id = $1
			`
			args = []interface{}{orderID, status}
		}
	} else if status == "cancelled" {
		if driverID != "" {
			query = `
				UPDATE orders
				SET status = $2, cancelled_at = NOW(), cancelled_by = 'driver', updated_at = NOW()
				WHERE id = $1 AND (driver_id = $3 OR driver_id IS NULL)
			`
			args = []interface{}{orderID, status, driverID}
		} else {
			query = `
				UPDATE orders
				SET status = $2, cancelled_at = NOW(), updated_at = NOW()
				WHERE id = $1
			`
			args = []interface{}{orderID, status}
		}
	} else {
		if driverID != "" {
			query = `
				UPDATE orders
				SET status = $2, updated_at = NOW()
				WHERE id = $1 AND (driver_id = $3 OR driver_id IS NULL)
			`
			args = []interface{}{orderID, status, driverID}
		} else {
			query = `
				UPDATE orders
				SET status = $2, updated_at = NOW()
				WHERE id = $1
			`
			args = []interface{}{orderID, status}
		}
	}
	cmd, err := r.db.Exec(ctx, query, args...)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("order not found or unauthorized driver")
	}
	return nil
}

type ActiveDriverTrip struct {
	ID             string    `json:"id"`
	ServiceType    string    `json:"service_type"`
	Status         string    `json:"status"`
	CustomerName   string    `json:"customer_name"`
	CustomerPhone  string    `json:"customer_phone"`
	CustomerRating float64   `json:"customer_rating"`
	PickupAddress  string    `json:"pickup_address"`
	PickupLat      float64   `json:"pickup_lat"`
	PickupLng      float64   `json:"pickup_lng"`
	DropoffAddress string    `json:"dropoff_address"`
	DropoffLat     float64   `json:"dropoff_lat"`
	DropoffLng     float64   `json:"dropoff_lng"`
	DistanceKm     float64   `json:"distance_km"`
	DurationMin    int       `json:"duration_min"`
	FareEstimate   float64   `json:"fare_estimate"`
	PaymentMethod  string    `json:"payment_method"`
	VehicleType    string    `json:"vehicle_type"`
	StartedAt      time.Time `json:"started_at"`
	NextAction     string    `json:"next_action"`
}

func (r *PostgresRepo) GetCurrentTrip(ctx context.Context, driverID string) (*ActiveDriverTrip, error) {
	query := `
		SELECT o.id, o.service_type, o.status, COALESCE(u.full_name, 'Khách hàng'), COALESCE(u.phone, ''),
		       o.pickup_address,
		       ST_Y(o.pickup_location::geometry) as pickup_lat,
		       ST_X(o.pickup_location::geometry) as pickup_lng,
		       o.dropoff_address,
		       ST_Y(o.dropoff_location::geometry) as dropoff_lat,
		       ST_X(o.dropoff_location::geometry) as dropoff_lng,
		       COALESCE(o.distance_km, 3.5), COALESCE(o.duration_minutes, 15),
		       o.fare_estimate, o.payment_method, COALESCE(o.vehicle_type, 'car'),
		       COALESCE(o.accepted_at, o.created_at)
		FROM orders o
		LEFT JOIN users u ON o.customer_id = u.id
		WHERE o.driver_id = $1 AND o.status IN ('accepted', 'arriving', 'arrived', 'in_progress')
		ORDER BY o.updated_at DESC
		LIMIT 1
	`
	var t ActiveDriverTrip
	t.CustomerRating = 4.9
	err := r.db.QueryRow(ctx, query, driverID).Scan(
		&t.ID, &t.ServiceType, &t.Status, &t.CustomerName, &t.CustomerPhone,
		&t.PickupAddress, &t.PickupLat, &t.PickupLng,
		&t.DropoffAddress, &t.DropoffLat, &t.DropoffLng,
		&t.DistanceKm, &t.DurationMin,
		&t.FareEstimate, &t.PaymentMethod, &t.VehicleType,
		&t.StartedAt,
	)
	if err != nil {
		return nil, err
	}

	nextActions := map[string]string{
		"accepted":    "Đang đến điểm đón khách",
		"arriving":    "Sắp đến điểm đón",
		"arrived":     "Đã đến điểm đón, chờ khách lên xe",
		"in_progress": "Đang di chuyển đến điểm trả khách",
	}
	t.NextAction = nextActions[t.Status]
	if t.NextAction == "" {
		t.NextAction = "Đang thực hiện chuyến đi"
	}
	return &t, nil
}

type DriverEarningsSummary struct {
	TodayEarnings float64                  `json:"today_earnings"`
	TodayTrips    int                      `json:"today_trips"`
	WeekEarnings  float64                  `json:"week_earnings"`
	WeekTrips     int                      `json:"week_trips"`
	MonthEarnings float64                  `json:"month_earnings"`
	MonthTrips    int                      `json:"month_trips"`
	WeekDays      []map[string]interface{} `json:"week_days"`
}

func (r *PostgresRepo) GetDriverEarnings(ctx context.Context, driverID string) (*DriverEarningsSummary, error) {
	s := &DriverEarningsSummary{
		WeekDays: make([]map[string]interface{}, 0),
	}

	// 1. Today's completed orders
	todayQuery := `
		SELECT COALESCE(SUM(COALESCE(fare_final, fare_estimate)), 0), COUNT(*)
		FROM orders
		WHERE driver_id = $1 AND status = 'completed' AND created_at >= CURRENT_DATE
	`
	_ = r.db.QueryRow(ctx, todayQuery, driverID).Scan(&s.TodayEarnings, &s.TodayTrips)

	// 2. Week completed orders (last 7 days)
	weekQuery := `
		SELECT COALESCE(SUM(COALESCE(fare_final, fare_estimate)), 0), COUNT(*)
		FROM orders
		WHERE driver_id = $1 AND status = 'completed' AND created_at >= (CURRENT_DATE - INTERVAL '6 days')
	`
	_ = r.db.QueryRow(ctx, weekQuery, driverID).Scan(&s.WeekEarnings, &s.WeekTrips)

	// 3. Month completed orders
	monthQuery := `
		SELECT COALESCE(SUM(COALESCE(fare_final, fare_estimate)), 0), COUNT(*)
		FROM orders
		WHERE driver_id = $1 AND status = 'completed' AND created_at >= DATE_TRUNC('month', CURRENT_DATE)
	`
	_ = r.db.QueryRow(ctx, monthQuery, driverID).Scan(&s.MonthEarnings, &s.MonthTrips)

	// 4. Breakdown by day for last 7 days
	daysQuery := `
		SELECT TO_CHAR(d::date, 'DD/MM') as day_label,
		       COALESCE(SUM(COALESCE(o.fare_final, o.fare_estimate)), 0) as day_earnings,
		       COUNT(o.id) as day_trips
		FROM generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, '1 day'::interval) d
		LEFT JOIN orders o ON DATE(o.created_at) = d::date AND o.driver_id = $1 AND o.status = 'completed'
		GROUP BY d::date
		ORDER BY d::date ASC
	`
	rows, err := r.db.Query(ctx, daysQuery, driverID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var label string
			var earnings float64
			var trips int
			if err := rows.Scan(&label, &earnings, &trips); err == nil {
				s.WeekDays = append(s.WeekDays, map[string]interface{}{
					"date":     label,
					"earnings": earnings,
					"trips":    trips,
				})
			}
		}
	}

	return s, nil
}

type DriverHistoryItem struct {
	ID             string    `json:"id"`
	ServiceType    string    `json:"service_type"`
	Status         string    `json:"status"`
	CustomerName   string    `json:"customer_name"`
	CustomerPhone  string    `json:"customer_phone"`
	PickupAddress  string    `json:"pickup_address"`
	DropoffAddress string    `json:"dropoff_address"`
	DistanceKm     float64   `json:"distance_km"`
	Fare           float64   `json:"fare"`
	DriverEarning  float64   `json:"driver_earning"`
	PaymentMethod  string    `json:"payment_method"`
	CreatedAt      time.Time `json:"created_at"`
}

func (r *PostgresRepo) GetDriverHistory(ctx context.Context, driverID string, limit int) ([]DriverHistoryItem, error) {
	if limit <= 0 {
		limit = 20
	}
	query := `
		SELECT o.id, o.service_type, o.status, COALESCE(u.full_name, 'Khách hàng'), COALESCE(u.phone, ''),
		       o.pickup_address, o.dropoff_address,
		       COALESCE(o.distance_km, 3.5),
		       COALESCE(o.fare_final, o.fare_estimate),
		       o.payment_method, o.created_at
		FROM orders o
		LEFT JOIN users u ON o.customer_id = u.id
		WHERE o.driver_id = $1
		ORDER BY o.created_at DESC
		LIMIT $2
	`
	rows, err := r.db.Query(ctx, query, driverID, limit)
	if err != nil {
		return nil, fmt.Errorf("query driver history: %w", err)
	}
	defer rows.Close()

	var list []DriverHistoryItem
	for rows.Next() {
		var h DriverHistoryItem
		if err := rows.Scan(
			&h.ID, &h.ServiceType, &h.Status, &h.CustomerName, &h.CustomerPhone,
			&h.PickupAddress, &h.DropoffAddress,
			&h.DistanceKm, &h.Fare,
			&h.PaymentMethod, &h.CreatedAt,
		); err != nil {
			return nil, err
		}
		h.DriverEarning = h.Fare * 0.8
		list = append(list, h)
	}
	return list, nil
}

func (r *PostgresRepo) GetDriverApprovalStatus(ctx context.Context, driverID string) (string, error) {
	var status string
	// Fail-closed: callers must treat a lookup error as "not approved".
	err := r.db.QueryRow(ctx, "SELECT COALESCE(approval_status, 'unverified') FROM users WHERE id = $1 AND is_active = TRUE", driverID).Scan(&status)
	if err != nil {
		return "", fmt.Errorf("lookup driver approval status: %w", err)
	}
	return status, nil
}


