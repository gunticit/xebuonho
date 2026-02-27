package model

import (
	"time"
)

// Merchant represents a restaurant or store
type Merchant struct {
	ID             string    `json:"id"`
	OwnerID        string    `json:"owner_id"`
	Name           string    `json:"name"`
	Description    string    `json:"description"`
	Category       string    `json:"category"`
	Phone          string    `json:"phone"`
	Email          string    `json:"email"`
	Latitude       float64   `json:"latitude"`
	Longitude      float64   `json:"longitude"`
	Address        string    `json:"address"`
	LogoURL        string    `json:"logo_url"`
	CoverURL       string    `json:"cover_url"`
	Rating         float64   `json:"rating"`
	TotalOrders    int32     `json:"total_orders"`
	IsActive       bool      `json:"is_active"`
	IsVerified     bool      `json:"is_verified"`
	OperatingHours string    `json:"operating_hours"` // JSON string
	CommissionRate float64   `json:"commission_rate"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`

	// Computed fields (not stored)
	DistanceKm      float64 `json:"distance_km,omitempty"`
	DeliveryTimeMin int32   `json:"delivery_time_min,omitempty"`
	IsOpenNow       bool    `json:"is_open_now,omitempty"`
}

// MenuItem represents a product in a merchant's menu
type MenuItem struct {
	ID              string       `json:"id"`
	MerchantID      string       `json:"merchant_id"`
	CategoryName    string       `json:"category_name"`
	Name            string       `json:"name"`
	Description     string       `json:"description"`
	Price           float64      `json:"price"`
	ImageURL        string       `json:"image_url"`
	IsAvailable     bool         `json:"is_available"`
	PreparationTime int32        `json:"preparation_time_min"`
	Options         []MenuOption `json:"options"`
	SortOrder       int32        `json:"sort_order"`
	CreatedAt       time.Time    `json:"created_at"`
	UpdatedAt       time.Time    `json:"updated_at"`
}

// MenuOption represents customization options (Size, Topping, etc.)
type MenuOption struct {
	Name        string             `json:"name"`
	Required    bool               `json:"required"`
	MultiSelect bool               `json:"multi_select"`
	Choices     []MenuOptionChoice `json:"choices"`
}

// MenuOptionChoice represents a single choice within an option
type MenuOptionChoice struct {
	Name       string  `json:"name"`
	ExtraPrice float64 `json:"extra_price"`
}

// MenuCategory groups menu items by category
type MenuCategory struct {
	Name  string     `json:"name"`
	Items []MenuItem `json:"items"`
}

// CreateMerchantInput is the input for creating a new merchant
type CreateMerchantInput struct {
	OwnerID     string
	Name        string
	Description string
	Category    string
	Phone       string
	Latitude    float64
	Longitude   float64
	Address     string
	LogoURL     string
}

// CreateMenuItemInput is the input for creating a new menu item
type CreateMenuItemInput struct {
	MerchantID      string
	CategoryName    string
	Name            string
	Description     string
	Price           float64
	ImageURL        string
	PreparationTime int32
	Options         []MenuOption
}
