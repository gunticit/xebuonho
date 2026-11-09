package model

import "time"

type DriverLocation struct {
	DriverID  string    `json:"driver_id"`
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	Heading   float64   `json:"heading"`
	Speed     float64   `json:"speed"`
	Timestamp time.Time `json:"timestamp"`
}

type LocationUpdate struct {
	DriverID  string    `json:"driver_id"`
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	Heading   float64   `json:"heading"`
	Speed     float64   `json:"speed"` // km/h
	IsMock    bool      `json:"is_mock,omitempty"` // Anti-fraud: mock location flag
	Timestamp time.Time `json:"timestamp,omitempty"`
}
