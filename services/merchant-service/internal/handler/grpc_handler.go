package handler

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/xebuonho/services/merchant-service/internal/model"
	"github.com/xebuonho/services/merchant-service/internal/service"
)

// MerchantGRPCHandler implements the gRPC MerchantService
type MerchantGRPCHandler struct {
	svc *service.MerchantService
}

// NewMerchantGRPCHandler creates a new handler
func NewMerchantGRPCHandler(svc *service.MerchantService) *MerchantGRPCHandler {
	return &MerchantGRPCHandler{svc: svc}
}

// ListNearbyMerchants returns merchants within a radius
func (h *MerchantGRPCHandler) ListNearbyMerchants(ctx context.Context, lat, lng, radiusKm float64, category, sortBy string, page, pageSize int) ([]model.Merchant, int, error) {
	merchants, total, err := h.svc.ListNearbyMerchants(ctx, lat, lng, radiusKm, category, sortBy, page, pageSize)
	if err != nil {
		return nil, 0, status.Errorf(codes.Internal, "list nearby merchants: %v", err)
	}
	return merchants, total, nil
}

// GetMerchant returns a merchant by ID
func (h *MerchantGRPCHandler) GetMerchant(ctx context.Context, merchantID string) (*model.Merchant, error) {
	merchant, err := h.svc.GetMerchant(ctx, merchantID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "merchant not found: %v", err)
	}
	return merchant, nil
}

// GetMenu returns the full menu for a merchant
func (h *MerchantGRPCHandler) GetMenu(ctx context.Context, merchantID string) ([]model.MenuCategory, error) {
	menu, err := h.svc.GetMenu(ctx, merchantID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "get menu: %v", err)
	}
	return menu, nil
}

// SearchMerchants searches merchants by query
func (h *MerchantGRPCHandler) SearchMerchants(ctx context.Context, query string, lat, lng, radiusKm float64, page, pageSize int) ([]model.Merchant, int, error) {
	merchants, total, err := h.svc.SearchMerchants(ctx, query, lat, lng, radiusKm, page, pageSize)
	if err != nil {
		return nil, 0, status.Errorf(codes.Internal, "search merchants: %v", err)
	}
	return merchants, total, nil
}

// CreateMerchant creates a new merchant
func (h *MerchantGRPCHandler) CreateMerchant(ctx context.Context, input model.CreateMerchantInput) (*model.Merchant, error) {
	merchant, err := h.svc.CreateMerchant(ctx, input)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "%v", err)
	}
	return merchant, nil
}

// UpdateMerchant updates a merchant
func (h *MerchantGRPCHandler) UpdateMerchant(ctx context.Context, id, name, description, phone, logoURL, operatingHours string, isActive bool) (*model.Merchant, error) {
	merchant, err := h.svc.UpdateMerchant(ctx, id, name, description, phone, logoURL, operatingHours, isActive)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update merchant: %v", err)
	}
	return merchant, nil
}

// CreateMenuItem creates a new menu item
func (h *MerchantGRPCHandler) CreateMenuItem(ctx context.Context, input model.CreateMenuItemInput) (*model.MenuItem, error) {
	item, err := h.svc.CreateMenuItem(ctx, input)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "%v", err)
	}
	return item, nil
}

// UpdateMenuItem updates a menu item
func (h *MerchantGRPCHandler) UpdateMenuItem(ctx context.Context, id, name, description, imageURL string, price float64, isAvailable bool) (*model.MenuItem, error) {
	item, err := h.svc.UpdateMenuItem(ctx, id, name, description, imageURL, price, isAvailable)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update menu item: %v", err)
	}
	return item, nil
}

// ToggleItemAvailability toggles item availability
func (h *MerchantGRPCHandler) ToggleItemAvailability(ctx context.Context, id string, available bool) (*model.MenuItem, error) {
	item, err := h.svc.ToggleItemAvailability(ctx, id, available)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "toggle availability: %v", err)
	}
	return item, nil
}

// ValidateAndPriceItems validates items and returns pricing
func (h *MerchantGRPCHandler) ValidateAndPriceItems(ctx context.Context, merchantID string, items []service.ItemRequest) (*service.ValidateResult, error) {
	result, err := h.svc.ValidateAndPriceItems(ctx, merchantID, items)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "validate items: %v", err)
	}
	return result, nil
}
