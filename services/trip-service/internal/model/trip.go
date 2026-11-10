package model

import "time"

// Trip is a finished journey read from the unified orders table.
// It covers all 4 service types (ride, food_delivery, grocery, designated_driver).
type Trip struct {
	ID             string     `json:"id"`
	ServiceType    string     `json:"service_type"`
	Status         string     `json:"status"`
	CustomerID     string     `json:"customer_id"`
	DriverID       *string    `json:"driver_id"`
	DriverName     string     `json:"driver_name,omitempty"`
	DriverVehicle  string     `json:"driver_vehicle,omitempty"`
	PickupAddress  string     `json:"pickup_address"`
	DropoffAddress string     `json:"dropoff_address"`
	VehicleType    string     `json:"vehicle_type,omitempty"`
	FareEstimate   float64    `json:"fare_estimate"`
	FareFinal      *float64   `json:"fare_final"`
	DistanceKm     *float64   `json:"distance_km"`
	DurationMin    *int       `json:"duration_min"`
	PaymentMethod  string     `json:"payment_method"`
	CancelledBy    string     `json:"cancelled_by,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	CompletedAt    *time.Time `json:"completed_at"`

	// Rating given by the customer for this order (nullable until rated).
	Rating    *int     `json:"rating"`
	TipAmount *float64 `json:"tip_amount"`
	Comment   *string  `json:"comment"`
}

// SubmitRatingRequest is the payload for POST /trips/{id}/rating.
type SubmitRatingRequest struct {
	Rating    int     `json:"rating"`
	TipAmount float64 `json:"tip_amount"`
	Comment   string  `json:"comment"`
}

// RatingSummary aggregates customer ratings for a driver.
type RatingSummary struct {
	DriverID      string  `json:"driver_id"`
	AverageRating float64 `json:"average_rating"`
	TotalRatings  int     `json:"total_ratings"`
	TotalTips     float64 `json:"total_tips"`
}
