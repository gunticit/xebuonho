package model

// NearbyDriver represents a candidate driver discovered near a pickup point
type NearbyDriver struct {
	DriverID        string   `json:"driver_id"`
	Latitude        float64  `json:"latitude"`
	Longitude       float64  `json:"longitude"`
	DistanceKm      float64  `json:"distance_km"`
	Rating          float64  `json:"rating"`
	ETAMinutes      float64  `json:"eta_minutes"`
	WaitTimeMinutes float64  `json:"wait_time_minutes"`
	Capabilities    []string `json:"capabilities"`
	VehicleType     string   `json:"vehicle_type"`
	Status          string   `json:"status"`
	Score           float64  `json:"score"`
}

// DriverMeta contains cached driver metadata read from Redis driver:{id}:meta
type DriverMeta struct {
	DriverID        string   `json:"driver_id"`
	Status          string   `json:"status"`
	Rating          float64  `json:"rating"`
	VehicleType     string   `json:"vehicle_type"`
	Capabilities    []string `json:"capabilities"`
	WaitTimeMinutes float64  `json:"wait_time_minutes"`
	LastUpdated     int64    `json:"last_updated"`
}

// MatchRequest contains payload to request driver matching
type MatchRequest struct {
	OrderID           string  `json:"order_id"`
	CustomerID        string  `json:"customer_id,omitempty"`
	ServiceType       string  `json:"service_type"` // ride, food, grocery, designated_driver
	PickupLat         float64 `json:"pickup_lat"`
	PickupLng         float64 `json:"pickup_lng"`
	PreferredRadiusKm float64 `json:"preferred_radius_km,omitempty"`
}

// MatchResponse returns the result of driver matching
type MatchResponse struct {
	OrderID         string        `json:"order_id"`
	MatchedDriver   *NearbyDriver `json:"matched_driver,omitempty"`
	SearchRadiusKm  float64       `json:"search_radius_km"`
	Status          string        `json:"status"` // driver_assigned or no_driver
	CandidatesFound int           `json:"candidates_found"`
	Message         string        `json:"message"`
}
