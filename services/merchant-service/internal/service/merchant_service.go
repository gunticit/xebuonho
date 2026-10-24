package service

import (
	"context"
	"fmt"
	"log"

	"github.com/xebuonho/pkg/kafka"
	"github.com/xebuonho/services/merchant-service/internal/model"
	"github.com/xebuonho/services/merchant-service/internal/repository"
)

type OrderServiceClient interface {
	UpdateOrderStatus(ctx context.Context, orderID, actorID, actorRole, event string) error
}

type MerchantService interface {
	CreateMerchant(ctx context.Context, input model.CreateMerchantInput) (*model.Merchant, error)
	GetMerchant(ctx context.Context, id string) (*model.Merchant, error)
	UpdateMerchant(ctx context.Context, id, name, description, phone, logoURL, operatingHours string, isActive bool) (*model.Merchant, error)
	ListNearbyMerchants(ctx context.Context, lat, lng, radiusKm float64, category, sortBy string, page, pageSize int) ([]model.Merchant, int, error)
	SearchMerchants(ctx context.Context, query string, lat, lng, radiusKm float64, page, pageSize int) ([]model.Merchant, int, error)
	GetMenu(ctx context.Context, merchantID string) ([]model.MenuCategory, error)
	CreateMenuItem(ctx context.Context, input model.CreateMenuItemInput) (*model.MenuItem, error)
	UpdateMenuItem(ctx context.Context, id, name, description, imageURL string, price float64, isAvailable bool) (*model.MenuItem, error)
	ToggleItemAvailability(ctx context.Context, id string, available bool) (*model.MenuItem, error)
	ValidateAndPriceItems(ctx context.Context, merchantID string, itemRequests []ItemRequest) (*ValidateResult, error)

	// New methods for Food Delivery flow
	HandleOrderCreated(ctx context.Context, event kafka.OrderEventData) error
	ConfirmOrder(ctx context.Context, orderID, merchantID string, confirmed bool) error
}

type merchantService struct {
	merchantRepo *repository.MerchantRepository
	menuRepo     *repository.MenuRepository
	orderSvc     OrderServiceClient
}

func NewMerchantService(merchantRepo *repository.MerchantRepository, menuRepo *repository.MenuRepository, orderSvc OrderServiceClient) MerchantService {
	return &merchantService{
		merchantRepo: merchantRepo,
		menuRepo:     menuRepo,
		orderSvc:     orderSvc,
	}
}

func (s *merchantService) HandleOrderCreated(ctx context.Context, event kafka.OrderEventData) error {
	if event.ServiceType != "food_delivery" {
		return nil // Ignore non-food orders
	}

	log.Printf("[merchant-service] New food order received: %s. Notifying merchant...", event.OrderID)
	// In real implementation: Push notification to Merchant App via MQTT/Firebase
	return nil
}

func (s *merchantService) ConfirmOrder(ctx context.Context, orderID, merchantID string, confirmed bool) error {
	event := "merchant_confirmed"
	if !confirmed {
		event = "merchant_rejected"
	}

	log.Printf("[merchant-service] Merchant %s %s order %s", merchantID, event, orderID)

	// Call Order Service to update state machine
	err := s.orderSvc.UpdateOrderStatus(ctx, orderID, merchantID, "merchant", event)
	if err != nil {
		return fmt.Errorf("update order status: %w", err)
	}

	return nil
}

// ... (Previous methods from the original merchant_service.go remain the same)
func (s *merchantService) CreateMerchant(ctx context.Context, input model.CreateMerchantInput) (*model.Merchant, error) {
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

func (s *merchantService) GetMerchant(ctx context.Context, id string) (*model.Merchant, error) {
	if id == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	return s.merchantRepo.GetByID(ctx, id)
}

func (s *merchantService) UpdateMerchant(ctx context.Context, id, name, description, phone, logoURL, operatingHours string, isActive bool) (*model.Merchant, error) {
	if id == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	return s.merchantRepo.Update(ctx, id, name, description, phone, logoURL, operatingHours, isActive)
}

func (s *merchantService) ListNearbyMerchants(ctx context.Context, lat, lng, radiusKm float64, category, sortBy string, page, pageSize int) ([]model.Merchant, int, error) {
	if radiusKm <= 0 {
		radiusKm = 5.0
	}
	if radiusKm > 50 {
		radiusKm = 50
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

func (s *merchantService) SearchMerchants(ctx context.Context, query string, lat, lng, radiusKm float64, page, pageSize int) ([]model.Merchant, int, error) {
	if query == "" {
		return nil, 0, fmt.Errorf("search query is required")
	}
	if radiusKm <= 0 {
		radiusKm = 10.0
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
	return s.merchantRepo.Search(ctx, query, lat, lng, radiusKm, pageSize, offset)
}

func (s *merchantService) GetMenu(ctx context.Context, merchantID string) ([]model.MenuCategory, error) {
	if merchantID == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	return s.menuRepo.GetMenuByMerchant(ctx, merchantID)
}

func (s *merchantService) CreateMenuItem(ctx context.Context, input model.CreateMenuItemInput) (*model.MenuItem, error) {
	if input.MerchantID == "" {
		return nil, fmt.Errorf("merchant_id is required")
	}
	if input.Name == "" {
		return nil, fmt.Errorf("item name is required")
	}
	if input.Price <= 0 {
		return nil, fmt.Errorf("price must be positive")
	}
	_, err := s.merchantRepo.GetByID(ctx, input.MerchantID)
	if err != nil {
		return nil, fmt.Errorf("merchant not found: %w", err)
	}
	return s.menuRepo.Create(ctx, input)
}

func (s *merchantService) UpdateMenuItem(ctx context.Context, id, name, description, imageURL string, price float64, isAvailable bool) (*model.MenuItem, error) {
	if id == "" {
		return nil, fmt.Errorf("item_id is required")
	}
	return s.menuRepo.Update(ctx, id, name, description, imageURL, price, isAvailable)
}

func (s *merchantService) ToggleItemAvailability(ctx context.Context, id string, available bool) (*model.MenuItem, error) {
	if id == "" {
		return nil, fmt.Errorf("item_id is required")
	}
	return s.menuRepo.ToggleAvailability(ctx, id, available)
}

func (s *merchantService) ValidateAndPriceItems(ctx context.Context, merchantID string, itemRequests []ItemRequest) (*ValidateResult, error) {
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
	}
	if len(result.Items) > 0 {
		// Simple logic to find max prep time
		for _, item := range result.Items {
			//-’s a simplification
		}
	}
	result.EstimatedPrepTime = 15 // Default 15min
	return result, nil
}

type ItemRequest struct {
	MenuItemID string
	Quantity   int32
}

type ValidateResult struct {
	Valid             bool
	TotalPrice        float64
	EstimatedPrepTime int32
	Errors            []string
}

type ValidatedItem struct {
	MenuItemID  string
	Name        string
	Quantity    int32
	UnitPrice   float64
	TotalPrice  float64
	IsAvailable bool
}
