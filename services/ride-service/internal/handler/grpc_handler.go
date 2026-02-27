package handler

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/xebuonho/services/ride-service/internal/model"
	"github.com/xebuonho/services/ride-service/internal/service"
)

// RideGRPCHandler implements the gRPC RideService
type RideGRPCHandler struct {
	svc *service.RideService
}

// NewRideGRPCHandler creates a new handler
func NewRideGRPCHandler(svc *service.RideService) *RideGRPCHandler {
	return &RideGRPCHandler{svc: svc}
}

// CreateRide creates a new ride
func (h *RideGRPCHandler) CreateRide(ctx context.Context, riderID string,
	pickupLat, pickupLng float64, pickupAddr string,
	dropoffLat, dropoffLng float64, dropoffAddr,
	vehicleType, paymentMethod, promoCode, idempotencyKey string,
) (*model.Ride, *model.FareEstimate, error) {
	ride, fare, err := h.svc.CreateRide(ctx, riderID,
		pickupLat, pickupLng, pickupAddr,
		dropoffLat, dropoffLng, dropoffAddr,
		vehicleType, paymentMethod, promoCode, idempotencyKey)
	if err != nil {
		return nil, nil, status.Errorf(codes.InvalidArgument, "%v", err)
	}
	return ride, fare, nil
}

// GetRide retrieves a ride
func (h *RideGRPCHandler) GetRide(ctx context.Context, rideID string) (*model.Ride, error) {
	ride, err := h.svc.GetRide(ctx, rideID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "%v", err)
	}
	return ride, nil
}

// ListRides lists rides for a rider
func (h *RideGRPCHandler) ListRides(ctx context.Context, riderID string, page, pageSize int) ([]model.Ride, int, error) {
	rides, total, err := h.svc.ListRides(ctx, riderID, page, pageSize)
	if err != nil {
		return nil, 0, status.Errorf(codes.Internal, "%v", err)
	}
	return rides, total, nil
}

// EstimateFare estimates fare for a ride
func (h *RideGRPCHandler) EstimateFare(pickupLat, pickupLng, dropoffLat, dropoffLng float64, vehicleType string) model.FareEstimate {
	return h.svc.EstimateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, vehicleType)
}
