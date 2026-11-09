package model

import "time"

type Driver struct {
	ID                  string    `json:"id"`
	Name                string    `json:"name"`
	Phone               string    `json:"phone"`
	Status              string    `json:"status"` // "online", "offline", "busy"
	CurrentRideID       string    `json:"current_ride_id,omitempty"`
	LastLocation        Location  `json:"last_location"`
	UpdatedAt           time.Time `json:"updated_at"`

	// Driver KYC & Compliance (Nghị định 10/2020 & Thông tư Bộ GTVT)
	CCCDNumber          string    `json:"cccd_number,omitempty"`
	CCCDVerified        bool      `json:"cccd_verified"`
	DriverLicenseNumber string    `json:"driver_license_number,omitempty"`
	LicenseVerified     bool      `json:"license_verified"`
	CriminalRecordClear bool      `json:"criminal_record_clear"` // Lý lịch tư pháp số 2
	InsuranceValidUntil time.Time `json:"insurance_valid_until,omitempty"`
	KYCStatus           string    `json:"kyc_status"` // "pending", "verified", "suspended"
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
