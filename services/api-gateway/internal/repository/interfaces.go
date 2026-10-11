package repository

import (
	"context"
)

// OrderRepository (Repository Pattern) trừu tượng hóa các thao tác dữ liệu liên quan đến đơn hàng và cuốc xe
type OrderRepository interface {
	CreateRide(ctx context.Context, params CreateRideParams) (*RideResult, error)
	GetRide(ctx context.Context, rideID string) (*RideResult, error)
	ListPendingRides(ctx context.Context) ([]PendingRide, error)
	AcceptRide(ctx context.Context, orderID, driverID string) error
	UpdateRideStatus(ctx context.Context, orderID, driverID, status string) error
	GetCurrentTrip(ctx context.Context, driverID string) (*ActiveDriverTrip, error)
	GetDriverEarnings(ctx context.Context, driverID string) (*DriverEarningsSummary, error)
	GetDriverHistory(ctx context.Context, driverID string, limit int) ([]DriverHistoryItem, error)
}

// MerchantRepository (Repository Pattern) trừu tượng hóa các truy vấn danh bạ quán và thực đơn
type MerchantRepository interface {
	ListNearbyMerchants(ctx context.Context, lat, lng, radiusKm float64, category string) ([]MerchantItem, error)
	SearchMerchants(ctx context.Context, query string, lat, lng float64) ([]MerchantItem, error)
	GetMerchant(ctx context.Context, merchantID string) (*MerchantItem, error)
	GetMenu(ctx context.Context, merchantID string) ([]MenuItem, error)
}
