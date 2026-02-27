package model

import (
	"time"
)

// Order represents a unified order across all service types
type Order struct {
	ID             string  `json:"id"`
	IdempotencyKey string  `json:"idempotency_key"`
	ServiceType    string  `json:"service_type"` // ride, food_delivery, grocery, designated_driver
	CustomerID     string  `json:"customer_id"`
	DriverID       *string `json:"driver_id,omitempty"`
	MerchantID     *string `json:"merchant_id,omitempty"`
	ShadowDriverID *string `json:"shadow_driver_id,omitempty"`

	// Locations
	PickupLat      float64 `json:"pickup_lat"`
	PickupLng      float64 `json:"pickup_lng"`
	PickupAddress  string  `json:"pickup_address"`
	DropoffLat     float64 `json:"dropoff_lat"`
	DropoffLng     float64 `json:"dropoff_lng"`
	DropoffAddress string  `json:"dropoff_address"`

	VehicleType string `json:"vehicle_type,omitempty"`
	Status      string `json:"status"`

	// Pricing
	ItemsTotal      float64  `json:"items_total"`
	DeliveryFee     float64  `json:"delivery_fee"`
	ServiceFee      float64  `json:"service_fee"`
	SurgeMultiplier float64  `json:"surge_multiplier"`
	DiscountAmount  float64  `json:"discount_amount"`
	FareEstimate    float64  `json:"fare_estimate"`
	FareFinal       *float64 `json:"fare_final,omitempty"`

	PromoCode       string  `json:"promo_code,omitempty"`
	PaymentMethod   string  `json:"payment_method"`
	DistanceKm      float64 `json:"distance_km"`
	DurationMinutes int     `json:"duration_minutes"`

	// Timestamps
	CreatedAt    time.Time  `json:"created_at"`
	AcceptedAt   *time.Time `json:"accepted_at,omitempty"`
	PickedUpAt   *time.Time `json:"picked_up_at,omitempty"`
	DeliveredAt  *time.Time `json:"delivered_at,omitempty"`
	CompletedAt  *time.Time `json:"completed_at,omitempty"`
	CancelledAt  *time.Time `json:"cancelled_at,omitempty"`
	CancelledBy  string     `json:"cancelled_by,omitempty"`
	CancelReason string     `json:"cancel_reason,omitempty"`

	Metadata  string    `json:"metadata,omitempty"` // JSON
	UpdatedAt time.Time `json:"updated_at"`

	// Relations (loaded separately)
	Items []OrderItem `json:"items,omitempty"`
}

// OrderItem represents an item in a food/grocery order
type OrderItem struct {
	ID                   string    `json:"id"`
	OrderID              string    `json:"order_id"`
	MenuItemID           *string   `json:"menu_item_id,omitempty"`
	Name                 string    `json:"name"`
	Quantity             int32     `json:"quantity"`
	UnitPrice            float64   `json:"unit_price"`
	TotalPrice           float64   `json:"total_price"`
	OptionsSelected      string    `json:"options_selected,omitempty"` // JSON
	Unit                 string    `json:"unit,omitempty"`
	Notes                string    `json:"notes,omitempty"`
	IsSubstituted        bool      `json:"is_substituted"`
	OriginalName         string    `json:"original_name,omitempty"`
	SubstitutionApproved *bool     `json:"substitution_approved,omitempty"`
	Status               string    `json:"status"`
	CreatedAt            time.Time `json:"created_at"`
}

// VehicleInspection for designated driver
type VehicleInspection struct {
	ID              string    `json:"id"`
	OrderID         string    `json:"order_id"`
	DriverID        string    `json:"driver_id"`
	LicensePlate    string    `json:"license_plate"`
	VehicleModel    string    `json:"vehicle_model"`
	VehicleColor    string    `json:"vehicle_color"`
	OdometerKm      int       `json:"odometer_km"`
	FuelLevel       string    `json:"fuel_level"`
	PhotoFrontURL   string    `json:"photo_front_url"`
	PhotoBackURL    string    `json:"photo_back_url"`
	PhotoLeftURL    string    `json:"photo_left_url"`
	PhotoRightURL   string    `json:"photo_right_url"`
	ExistingDamages string    `json:"existing_damages"`
	Type            string    `json:"type"` // "pickup" or "dropoff"
	InspectedAt     time.Time `json:"inspected_at"`
}

// CreateOrderInput holds validated input for creating an order
type CreateOrderInput struct {
	ServiceType       string
	CustomerID        string
	IdempotencyKey    string
	PickupLat         float64
	PickupLng         float64
	PickupAddress     string
	DropoffLat        float64
	DropoffLng        float64
	DropoffAddress    string
	VehicleType       string
	MerchantID        string
	Items             []OrderItemInput
	ShoppingList      []ShoppingListInput
	PaymentMethod     string
	PromoCode         string
	DesignatedOptions *DesignatedDriverInput
}

// OrderItemInput for food delivery orders
type OrderItemInput struct {
	MenuItemID string
	Quantity   int32
	Notes      string
}

// ShoppingListInput for grocery orders
type ShoppingListInput struct {
	Name              string
	Quantity          int32
	Unit              string
	EstimatedPrice    float64
	Notes             string
	AllowSubstitution bool
}

// DesignatedDriverInput for designated driver orders
type DesignatedDriverInput struct {
	ShadowMode      string // "solo" or "duo"
	VehicleType     string
	LicensePlate    string
	HasParkingSpace bool
}
