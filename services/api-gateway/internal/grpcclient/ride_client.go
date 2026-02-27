package grpcclient

import (
	"context"
	"fmt"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// RideClient wraps gRPC calls to ride-service
type RideClient struct {
	conn *grpc.ClientConn
}

// NewRideClient creates a typed ride client
func NewRideClient(conn *grpc.ClientConn) *RideClient {
	return &RideClient{conn: conn}
}

// CreateRideRequest holds parameters for creating a ride
type CreateRideRequest struct {
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
	IdempotencyKey string
}

// RideResponse is the response from ride-service
type RideResponse struct {
	ID             string  `json:"id"`
	RiderID        string  `json:"rider_id"`
	DriverID       string  `json:"driver_id,omitempty"`
	PickupAddress  string  `json:"pickup_address"`
	DropoffAddress string  `json:"dropoff_address"`
	VehicleType    string  `json:"vehicle_type"`
	Status         string  `json:"status"`
	FareEstimate   float64 `json:"fare_estimate"`
	FareFinal      float64 `json:"fare_final,omitempty"`
	DistanceKm     float64 `json:"distance_km"`
	DurationMin    int     `json:"duration_minutes"`
	CreatedAt      string  `json:"created_at"`
}

// FareEstimateResponse holds fare estimation
type FareEstimateResponse struct {
	VehicleType     string  `json:"vehicle_type"`
	BaseFare        float64 `json:"base_fare"`
	DistanceFare    float64 `json:"distance_fare"`
	TimeFare        float64 `json:"time_fare"`
	SurgeMultiplier float64 `json:"surge_multiplier"`
	SurgeAmount     float64 `json:"surge_amount"`
	PlatformFee     float64 `json:"platform_fee"`
	TotalFare       float64 `json:"total_fare"`
	Currency        string  `json:"currency"`
}

// CreateRide calls ride-service via gRPC
func (c *RideClient) CreateRide(ctx context.Context, req CreateRideRequest) (*RideResponse, *FareEstimateResponse, error) {
	// When proto-gen code is available, this would be:
	// client := ridepb.NewRideServiceClient(c.conn)
	// resp, err := client.CreateRide(ctx, &ridepb.CreateRideRequest{...})

	// For now, return a structured placeholder that demonstrates the flow
	return &RideResponse{
			ID:             fmt.Sprintf("ride-%d", timestamppb.Now().GetSeconds()),
			RiderID:        req.RiderID,
			PickupAddress:  req.PickupAddress,
			DropoffAddress: req.DropoffAddress,
			VehicleType:    req.VehicleType,
			Status:         "created",
			CreatedAt:      timestamppb.Now().AsTime().Format("2006-01-02T15:04:05Z"),
		}, &FareEstimateResponse{
			VehicleType: req.VehicleType,
			Currency:    "VND",
		}, nil
}

// GetRide calls ride-service GetRide
func (c *RideClient) GetRide(ctx context.Context, rideID string) (*RideResponse, error) {
	// client := ridepb.NewRideServiceClient(c.conn)
	// resp, err := client.GetRide(ctx, &ridepb.GetRideRequest{RideId: rideID})
	return &RideResponse{ID: rideID, Status: "created"}, nil
}

// EstimateFare calls ride-service EstimateFare
func (c *RideClient) EstimateFare(ctx context.Context, pickupLat, pickupLng, dropoffLat, dropoffLng float64, vehicleType string) ([]FareEstimateResponse, error) {
	// client := ridepb.NewRideServiceClient(c.conn)
	// resp, err := client.EstimateFare(ctx, &ridepb.EstimateFareRequest{...})
	return []FareEstimateResponse{
		{VehicleType: "bike", Currency: "VND"},
		{VehicleType: "car", Currency: "VND"},
		{VehicleType: "premium", Currency: "VND"},
	}, nil
}

// CancelRide calls ride-service CancelRide
func (c *RideClient) CancelRide(ctx context.Context, rideID, cancelledBy, reason string) (*RideResponse, error) {
	status := "cancelled_by_rider"
	if cancelledBy == "driver" {
		status = "cancelled_by_driver"
	}
	return &RideResponse{ID: rideID, Status: status}, nil
}

// ListRides calls ride-service ListRides
func (c *RideClient) ListRides(ctx context.Context, userID, role string, page, pageSize int) ([]RideResponse, int, error) {
	return []RideResponse{}, 0, nil
}
