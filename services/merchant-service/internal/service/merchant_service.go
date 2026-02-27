package service

import (
	"context"
	"fmt"

	"github.com/xebuonho/services/merchant-service/internal/model"
	"github.com/xebuonho/services/merchant-service/internal/repository"
)

// MerchantService handles merchant business logic
type MerchantService struct {
	merchantRepo *repository.MerchantRepository
	menuRepo     *repository.MenuRepository
}

// NewMerchantService creates a new merchant service
func NewMerchantService(merchantRepo *repository.MerchantRepository, menuRepo *repository.MenuRepository) *MerchantService {
	return &MerchantService{
		merchantRepo: merchantRepo,
		menuRepo:     menuRepo,
	}
}

// CreateMerchant creates a new merchant
func (s *MerchantService) CreateMerchant(ctx context.Context, input model.CreateMerchantInput) (*model.Merchant, error) {
	if input.Name == "" {
		return nil, fmt.Errorf("merchant name is required")
	}
	if input.Category == "" {
		return nil, fmt.Errorf("category is required")
	}
	if input.Latitude == 0 || input.Longitude == 0 {
		return nil, fmt.Errorf("valid location is required")
	}
	return s.merchantRepo.Create(ctx, input)
}

// GetMerchant retrieves a merchant by ID
func (s *MerchantService) GetMerchant(ctx context.Context, id string) (*model.Merchant, error) {
	if id == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	return s.merchantRepo.GetByID(ctx, id)
}

// UpdateMerchant updates a merchant
func (s *MerchantService) UpdateMerchant(ctx context.Context, id, name, description, phone, logoURL, operatingHours string, isActive bool) (*model.Merchant, error) {
	if id == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	return s.merchantRepo.Update(ctx, id, name, description, phone, logoURL, operatingHours, isActive)
}

// ListNearbyMerchants finds merchants within a radius
func (s *MerchantService) ListNearbyMerchants(ctx context.Context, lat, lng, radiusKm float64, category, sortBy string, page, pageSize int) ([]model.Merchant, int, error) {
	if radiusKm <= 0 {
		radiusKm = 5.0 // Default 5km radius
	}
	if radiusKm > 50 {
		radiusKm = 50 // Max 50km
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	if pageSize > 100 {
		pageSize = 100
	}
	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}

	return s.merchantRepo.ListNearby(ctx, lat, lng, radiusKm, category, sortBy, pageSize, offset)
}

// SearchMerchants searches merchants by query
func (s *MerchantService) SearchMerchants(ctx context.Context, query string, lat, lng, radiusKm float64, page, pageSize int) ([]model.Merchant, int, error) {
	if query == "" {
		return nil, 0, fmt.Errorf("search query is required")
	}
	if radiusKm <= 0 {
		radiusKm = 10.0
	}
	if pageSize <= 0 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}

	return s.merchantRepo.Search(ctx, query, lat, lng, radiusKm, pageSize, offset)
}

// GetMenu retrieves the full menu for a merchant
func (s *MerchantService) GetMenu(ctx context.Context, merchantID string) ([]model.MenuCategory, error) {
	if merchantID == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	return s.menuRepo.GetMenuByMerchant(ctx, merchantID)
}

// CreateMenuItem adds a new item to a merchant's menu
func (s *MerchantService) CreateMenuItem(ctx context.Context, input model.CreateMenuItemInput) (*model.MenuItem, error) {
	if input.MerchantID == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	if input.Name == "" {
		return nil, fmt.Errorf("item name is required")
	}
	if input.Price <= 0 {
		return nil, fmt.Errorf("price must be positive")
	}

	// Verify merchant exists
	_, err := s.merchantRepo.GetByID(ctx, input.MerchantID)
	if err != nil {
		return nil, fmt.Errorf("merchant not found: %w", err)
	}

	return s.menuRepo.Create(ctx, input)
}

// UpdateMenuItem updates a menu item
func (s *MerchantService) UpdateMenuItem(ctx context.Context, id, name, description, imageURL string, price float64, isAvailable bool) (*model.MenuItem, error) {
	if id == "" {
		return nil, fmt.Errorf("item_id is required")
	}
	return s.menuRepo.Update(ctx, id, name, description, imageURL, price, isAvailable)
}

// ToggleItemAvailability toggles item availability
func (s *MerchantService) ToggleItemAvailability(ctx context.Context, id string, available bool) (*model.MenuItem, error) {
	if id == "" {
		return nil, fmt.Errorf("item_id is required")
	}
	return s.menuRepo.ToggleAvailability(ctx, id, available)
}

// ValidateAndPriceItems validates items and calculates total price
func (s *MerchantService) ValidateAndPriceItems(ctx context.Context, merchantID string, itemRequests []ItemRequest) (*ValidateResult, error) {
	itemIDs := make([]string, len(itemRequests))
	quantities := make(map[string]int32)
	for i, req := range itemRequests {
		itemIDs[i] = req.MenuItemID
		quantities[req.MenuItemID] = req.Quantity
	}

	items, err := s.menuRepo.ValidateItems(ctx, merchantID, itemIDs)
	if err != nil {
		return nil, err
	}

	result := &ValidateResult{Valid: true}
	itemMap := make(map[string]model.MenuItem)
	for _, item := range items {
		itemMap[item.ID] = item
	}

	var maxPrepTime int32
	for _, req := range itemRequests {
		item, found := itemMap[req.MenuItemID]
		if !found {
			result.Valid = false
			result.Errors = append(result.Errors, fmt.Sprintf("Item %s not found", req.MenuItemID))
			continue
		}
		if !item.IsAvailable {
			result.Valid = false
			result.Errors = append(result.Errors, fmt.Sprintf("%s đã hết", item.Name))
			continue
		}

		total := item.Price * float64(req.Quantity)
		result.Items = append(result.Items, ValidatedItem{
			MenuItemID:  item.ID,
			Name:        item.Name,
			Quantity:    req.Quantity,
			UnitPrice:   item.Price,
			TotalPrice:  total,
			IsAvailable: item.IsAvailable,
		})
		result.TotalPrice += total

		if item.PreparationTime > maxPrepTime {
			maxPrepTime = item.PreparationTime
		}
	}
	result.EstimatedPrepTime = maxPrepTime

	return result, nil
}

// ItemRequest for ValidateAndPriceItems
type ItemRequest struct {
	MenuItemID string
	Quantity   int32
}

// ValidateResult holds validation results
type ValidateResult struct {
	Valid             bool
	TotalPrice        float64
	EstimatedPrepTime int32
	Items             []ValidatedItem
	Errors            []string
}

// ValidatedItem represents a validated menu item with pricing
type ValidatedItem struct {
	MenuItemID  string
	Name        string
	Quantity    int32
	UnitPrice   float64
	TotalPrice  float64
	IsAvailable bool
}
