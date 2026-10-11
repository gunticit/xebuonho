package repository

import (
	"context"
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
}

type RideResult struct {
	ID             string    `json:"id"`
	ServiceType    string    `json:"service_type"`
	RiderID        string    `json:"rider_id"`
	PickupAddress  string    `json:"pickup_address"`
	DropoffAddress string    `json:"dropoff_address"`
	VehicleType    string    `json:"vehicle_type"`
	Status         string    `json:"status"`
	FareEstimate   float64   `json:"fare_estimate"`
	DistanceKm     float64   `json:"distance_km"`
	DurationMin    int       `json:"duration_minutes"`
	CreatedAt      time.Time `json:"created_at"`
}

func (r *PostgresRepo) CreateRide(ctx context.Context, p CreateRideParams) (*RideResult, error) {
	serviceType := p.ServiceType
	if serviceType == "" {
		serviceType = "ride"
	}

	query := `
		INSERT INTO orders (
			idempotency_key, service_type, customer_id,
			pickup_location, pickup_address, dropoff_location, dropoff_address,
			vehicle_type, status, fare_estimate, payment_method, promo_code,
			distance_km, duration_minutes
		) VALUES (
			$1, $2, $3,
			ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, $6,
			ST_SetSRID(ST_MakePoint($7, $8), 4326)::geography, $9,
			$10, 'created', $11, $12, $13, $14, $15
		)
		ON CONFLICT (idempotency_key) DO UPDATE SET updated_at = NOW()
		RETURNING id, service_type, customer_id, pickup_address, dropoff_address, vehicle_type, status,
		          fare_estimate, COALESCE(distance_km, 0), COALESCE(duration_minutes, 0), created_at
	`

	res := &RideResult{}
	err := r.db.QueryRow(ctx, query,
		p.IdempotencyKey, serviceType, p.RiderID,
		p.PickupLng, p.PickupLat, p.PickupAddress,
		p.DropoffLng, p.DropoffLat, p.DropoffAddress,
		p.VehicleType, p.FareEstimate, p.PaymentMethod, p.PromoCode,
		p.DistanceKm, p.DurationMin,
	).Scan(
		&res.ID, &res.ServiceType, &res.RiderID, &res.PickupAddress, &res.DropoffAddress,
		&res.VehicleType, &res.Status, &res.FareEstimate,
		&res.DistanceKm, &res.DurationMin, &res.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("insert ride order: %w", err)
	}
	return res, nil
}

func (r *PostgresRepo) GetRide(ctx context.Context, rideID string) (*RideResult, error) {
	query := `
		SELECT id, customer_id, pickup_address, dropoff_address, vehicle_type, status,
		       fare_estimate, COALESCE(distance_km, 0), COALESCE(duration_minutes, 0), created_at
		FROM orders
		WHERE id = $1
	`
	res := &RideResult{}
	err := r.db.QueryRow(ctx, query, rideID).Scan(
		&res.ID, &res.RiderID, &res.PickupAddress, &res.DropoffAddress,
		&res.VehicleType, &res.Status, &res.FareEstimate,
		&res.DistanceKm, &res.DurationMin, &res.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get ride: %w", err)
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
	query := `
		UPDATE orders
		SET driver_id = $2, status = 'accepted', accepted_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND status = 'created' AND customer_id != $2
	`
	cmd, err := r.db.Exec(ctx, query, orderID, driverID)
	if err != nil {
		return fmt.Errorf("accept ride: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("ride already accepted, not found, or driver cannot accept own ride")
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


