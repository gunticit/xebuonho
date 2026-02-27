package handler

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/xebuonho/services/order-service/internal/model"
	"github.com/xebuonho/services/order-service/internal/service"
)

// OrderGRPCHandler implements the gRPC OrderService
type OrderGRPCHandler struct {
	svc *service.OrderService
}

// NewOrderGRPCHandler creates a new handler
func NewOrderGRPCHandler(svc *service.OrderService) *OrderGRPCHandler {
	return &OrderGRPCHandler{svc: svc}
}

// CreateOrder creates a new unified order
func (h *OrderGRPCHandler) CreateOrder(ctx context.Context, input model.CreateOrderInput) (*model.Order, *service.PriceBreakdown, error) {
	order, price, err := h.svc.CreateOrder(ctx, input)
	if err != nil {
		return nil, nil, status.Errorf(codes.InvalidArgument, "%v", err)
	}
	return order, price, nil
}

// GetOrder retrieves an order with items
func (h *OrderGRPCHandler) GetOrder(ctx context.Context, orderID string) (*model.Order, error) {
	order, err := h.svc.GetOrder(ctx, orderID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "%v", err)
	}
	return order, nil
}

// UpdateOrderStatus transitions the order status
func (h *OrderGRPCHandler) UpdateOrderStatus(ctx context.Context, orderID, actorID, actorRole, event string) (*model.Order, error) {
	order, err := h.svc.UpdateOrderStatus(ctx, orderID, actorID, actorRole, event)
	if err != nil {
		return nil, status.Errorf(codes.FailedPrecondition, "%v", err)
	}
	return order, nil
}

// CancelOrder cancels an order
func (h *OrderGRPCHandler) CancelOrder(ctx context.Context, orderID, cancelledBy, reason string) (*model.Order, error) {
	order, err := h.svc.CancelOrder(ctx, orderID, cancelledBy, reason)
	if err != nil {
		return nil, status.Errorf(codes.FailedPrecondition, "%v", err)
	}
	return order, nil
}

// ListOrders lists orders with pagination
func (h *OrderGRPCHandler) ListOrders(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]model.Order, int, error) {
	orders, total, err := h.svc.ListOrders(ctx, userID, role, serviceType, page, pageSize)
	if err != nil {
		return nil, 0, status.Errorf(codes.Internal, "%v", err)
	}
	return orders, total, nil
}

// EstimatePrice estimates price for a service type
func (h *OrderGRPCHandler) EstimatePrice(serviceType, vehicleType string, distanceKm float64, durationMin int,
	itemsTotal float64, isDuo, isNight bool, surgeMultiplier float64) service.PriceBreakdown {
	return h.svc.EstimatePrice(serviceType, vehicleType, distanceKm, durationMin, itemsTotal, isDuo, isNight, surgeMultiplier)
}
