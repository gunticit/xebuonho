package model

import "time"

// Ride represents a ride request (thin wrapper, delegates to unified Order)
type Ride struct {
	ID             string     `json:"id"`
	RiderID        string     `json:"rider_id"`
	DriverID       *string    `json:"driver_id,omitempty"`
	PickupLat      float64    `json:"pickup_lat"`
	PickupLng      float64    `json:"pickup_lng"`
	PickupAddress  string     `json:"pickup_address"`
	DropoffLat     float64    `json:"dropoff_lat"`
	DropoffLng     float64    `json:"dropoff_lng"`
	DropoffAddress string     `json:"dropoff_address"`
	VehicleType    string     `json:"vehicle_type"`
	Status         string     `json:"status"`
	FareEstimate   float64    `json:"fare_estimate"`
	FareFinal      *float64   `json:"fare_final,omitempty"`
	PaymentMethod  string     `json:"payment_method"`
	PromoCode      string     `json:"promo_code,omitempty"`
	DistanceKm     float64    `json:"distance_km"`
	DurationMin    int        `json:"duration_minutes"`
	IdempotencyKey string     `json:"idempotency_key"`
	CreatedAt      time.Time  `json:"created_at"`
	AcceptedAt     *time.Time `json:"accepted_at,omitempty"`
	PickedUpAt     *time.Time `json:"picked_up_at,omitempty"`
	CompletedAt    *time.Time `json:"completed_at,omitempty"`
	CancelledAt    *time.Time `json:"cancelled_at,omitempty"`
	CancelledBy    string     `json:"cancelled_by,omitempty"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

// FareEstimate holds fare estimation result
type FareEstimate struct {
	BaseFare        float64 `json:"base_fare"`
	DistanceFare    float64 `json:"distance_fare"`
	TimeFare        float64 `json:"time_fare"`
	SurgeMultiplier float64 `json:"surge_multiplier"`
	SurgeAmount     float64 `json:"surge_amount"`
	PlatformFee     float64 `json:"platform_fee"`
	TotalFare       float64 `json:"total_fare"`
	Currency        string  `json:"currency"`
}
