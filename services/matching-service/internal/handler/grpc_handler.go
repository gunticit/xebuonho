package handler

import (
	"context"

	"github.com/xebuonho/services/matching-service/internal/model"
	"github.com/xebuonho/services/matching-service/internal/service"
)

// MatchingGRPCHandler implements gRPC calls for matching-service
type MatchingGRPCHandler struct {
	svc service.MatchingService
}

// NewMatchingGRPCHandler creates a new MatchingGRPCHandler
func NewMatchingGRPCHandler(svc service.MatchingService) *MatchingGRPCHandler {
	return &MatchingGRPCHandler{svc: svc}
}

// FindNearbyDrivers finds nearby drivers via internal service call
func (h *MatchingGRPCHandler) FindNearbyDrivers(ctx context.Context, lat, lng float64, radius float64, serviceType string, limit int) ([]model.NearbyDriver, error) {
	return h.svc.FindNearbyDrivers(ctx, lat, lng, radius, serviceType, limit)
}

// MatchDriver matches the best driver for an order via internal service call
func (h *MatchingGRPCHandler) MatchDriver(ctx context.Context, req model.MatchRequest) (*model.MatchResponse, error) {
	return h.svc.MatchDriver(ctx, req)
}
