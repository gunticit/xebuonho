package model

import "time"

type Driver struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Phone        string    `json:"phone"`
	Status       string    `json:"status"` // "online", "offline", "busy"
	CurrentRideID string  `json:"current_ride_id,omitempty"`
	LastLocation Location  `json:"last_location"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type Location struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

type RideNotification struct {
	RideID       string  `json:"ride_id"`
	PickupAddr   string  `json:"pickup_address"`
	DropoffAddr  string  `json:"dropoff_address"`
	FareEstimate float64 `json:"fare_estimate"`
	VehicleType  string  `json:"vehicle_type"`
}
