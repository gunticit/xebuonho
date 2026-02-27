package service

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/xebuonho/pkg/kafka"
	"github.com/xebuonho/pkg/statemachine"
	"github.com/xebuonho/services/order-service/internal/model"
	"github.com/xebuonho/services/order-service/internal/repository"
)

// OrderService handles order business logic
type OrderService struct {
	orderRepo     *repository.OrderRepository
	itemRepo      *repository.OrderItemRepository
	pricing       *PricingEngine
	stateMachines map[string]*statemachine.StateMachine
	eventProducer *kafka.Producer
}

// NewOrderService creates a new order service
func NewOrderService(orderRepo *repository.OrderRepository, itemRepo *repository.OrderItemRepository, producer *kafka.Producer) *OrderService {
	return &OrderService{
		orderRepo: orderRepo,
		itemRepo:  itemRepo,
		pricing:   NewPricingEngine(),
		stateMachines: map[string]*statemachine.StateMachine{
			"ride":              statemachine.NewStateMachine(statemachine.ServiceTypeRide),
			"food_delivery":     statemachine.NewStateMachine(statemachine.ServiceTypeFoodDelivery),
			"grocery":           statemachine.NewStateMachine(statemachine.ServiceTypeGrocery),
			"designated_driver": statemachine.NewStateMachine(statemachine.ServiceTypeDesignatedDriver),
		},
		eventProducer: producer,
	}
}

// CreateOrder creates a new order with idempotency check
func (s *OrderService) CreateOrder(ctx context.Context, input model.CreateOrderInput) (*model.Order, *PriceBreakdown, error) {
	// Validation
	if input.ServiceType == "" {
		return nil, nil, fmt.Errorf("service_type is required")
	}
	if input.CustomerID == "" {
		return nil, nil, fmt.Errorf("customer_id is required")
	}
	if input.IdempotencyKey == "" {
		return nil, nil, fmt.Errorf("idempotency_key is required")
	}

	// Idempotency check
	existing, err := s.orderRepo.GetByIdempotencyKey(ctx, input.IdempotencyKey)
	if err != nil {
		return nil, nil, fmt.Errorf("idempotency check: %w", err)
	}
	if existing != nil {
		return existing, nil, nil // Return existing order (duplicate request)
	}

	// Calculate price based on service type
	var price PriceBreakdown
	switch input.ServiceType {
	case "ride":
		price = s.pricing.CalculateRideFare(input.VehicleType, 0, 0, 1.0)
	case "food_delivery":
		var itemsTotal float64
		for _, item := range input.Items {
			itemsTotal += float64(item.Quantity) * 50000 // Placeholder; real price from merchant service
		}
		price = s.pricing.CalculateFoodDeliveryFee(itemsTotal, 0, 1.0)
	case "grocery":
		var estimatedTotal float64
		for _, item := range input.ShoppingList {
			estimatedTotal += item.EstimatedPrice * float64(item.Quantity)
		}
		price = s.pricing.CalculateGroceryFee(estimatedTotal, 0)
	case "designated_driver":
		isDuo := input.DesignatedOptions != nil && input.DesignatedOptions.ShadowMode == "duo"
		price = s.pricing.CalculateDesignatedDriverFare(0, 0, isDuo, false)
	default:
		return nil, nil, fmt.Errorf("invalid service_type: %s", input.ServiceType)
	}

	// Set initial status based on service type
	initialStatus := "created"
	if input.ServiceType == "food_delivery" {
		initialStatus = "placed"
	}

	// Build metadata
	var metadata string
	if input.DesignatedOptions != nil {
		metaBytes, _ := json.Marshal(input.DesignatedOptions)
		metadata = string(metaBytes)
	}
	if metadata == "" {
		metadata = "{}"
	}

	// Create order
	order := &model.Order{
		IdempotencyKey:  input.IdempotencyKey,
		ServiceType:     input.ServiceType,
		CustomerID:      input.CustomerID,
		PickupLat:       input.PickupLat,
		PickupLng:       input.PickupLng,
		PickupAddress:   input.PickupAddress,
		DropoffLat:      input.DropoffLat,
		DropoffLng:      input.DropoffLng,
		DropoffAddress:  input.DropoffAddress,
		VehicleType:     input.VehicleType,
		Status:          initialStatus,
		ItemsTotal:      price.ItemsTotal,
		DeliveryFee:     price.DeliveryFee,
		ServiceFee:      price.ServiceFee,
		SurgeMultiplier: price.SurgeMultiplier,
		DiscountAmount:  price.Discount,
		FareEstimate:    price.TotalEstimate,
		PromoCode:       input.PromoCode,
		PaymentMethod:   input.PaymentMethod,
		Metadata:        metadata,
	}

	if input.MerchantID != "" {
		order.MerchantID = &input.MerchantID
	}

	if err := s.orderRepo.Create(ctx, order); err != nil {
		return nil, nil, fmt.Errorf("create order: %w", err)
	}

	// Create order items (food_delivery or grocery)
	if len(input.Items) > 0 {
		var items []model.OrderItem
		for _, i := range input.Items {
			items = append(items, model.OrderItem{
				MenuItemID: &i.MenuItemID,
				Name:       i.MenuItemID, // Will be resolved from merchant service
				Quantity:   i.Quantity,
				Notes:      i.Notes,
				Status:     "pending",
			})
		}
		s.itemRepo.CreateBatch(ctx, order.ID, items)
	}

	if len(input.ShoppingList) > 0 {
		var items []model.OrderItem
		for _, sl := range input.ShoppingList {
			items = append(items, model.OrderItem{
				Name:       sl.Name,
				Quantity:   sl.Quantity,
				UnitPrice:  sl.EstimatedPrice,
				TotalPrice: sl.EstimatedPrice * float64(sl.Quantity),
				Unit:       sl.Unit,
				Notes:      sl.Notes,
				Status:     "pending",
			})
		}
		s.itemRepo.CreateBatch(ctx, order.ID, items)
	}

	// Publish order.created event
	if s.eventProducer != nil {
		s.eventProducer.PublishAsync(ctx, order.ID, kafka.EventOrderCreated, kafka.OrderEventData{
			OrderID:      order.ID,
			ServiceType:  order.ServiceType,
			CustomerID:   order.CustomerID,
			Status:       order.Status,
			FareEstimate: order.FareEstimate,
		})
	}

	return order, &price, nil
}

// GetOrder retrieves an order with items
func (s *OrderService) GetOrder(ctx context.Context, orderID string) (*model.Order, error) {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return nil, err
	}

	// Load items
	items, err := s.itemRepo.GetByOrderID(ctx, orderID)
	if err == nil {
		order.Items = items
	}

	return order, nil
}

// UpdateOrderStatus transitions the order status using the state machine
func (s *OrderService) UpdateOrderStatus(ctx context.Context, orderID, actorID, actorRole, event string) (*model.Order, error) {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return nil, err
	}

	sm, ok := s.stateMachines[order.ServiceType]
	if !ok {
		return nil, fmt.Errorf("unknown service type: %s", order.ServiceType)
	}

	// Convert to state machine order
	smOrder := &statemachine.Order{
		ID:          order.ID,
		ServiceType: statemachine.ServiceType(order.ServiceType),
		Status:      statemachine.OrderStatus(order.Status),
		DriverID:    order.DriverID,
	}

	if err := sm.ProcessEvent(smOrder, statemachine.OrderEvent(event)); err != nil {
		return nil, fmt.Errorf("invalid transition: %w", err)
	}

	// Update in DB
	if err := s.orderRepo.UpdateStatus(ctx, orderID, string(smOrder.Status)); err != nil {
		return nil, fmt.Errorf("update status: %w", err)
	}

	// Assign driver if event is driver_accepted
	if event == "driver_accepted" && actorRole == "driver" {
		s.orderRepo.AssignDriver(ctx, orderID, actorID)
	}

	order.Status = string(smOrder.Status)

	// Publish status change event
	if s.eventProducer != nil {
		driverID := ""
		if order.DriverID != nil {
			driverID = *order.DriverID
		}
		s.eventProducer.PublishAsync(ctx, order.ID, kafka.EventOrderStatusChanged, kafka.OrderEventData{
			OrderID:     order.ID,
			ServiceType: order.ServiceType,
			CustomerID:  order.CustomerID,
			DriverID:    driverID,
			Status:      order.Status,
		})
	}

	return order, nil
}

// CancelOrder cancels an order
func (s *OrderService) CancelOrder(ctx context.Context, orderID, cancelledBy, reason string) (*model.Order, error) {
	order, err := s.orderRepo.GetByID(ctx, orderID)
	if err != nil {
		return nil, err
	}

	sm, ok := s.stateMachines[order.ServiceType]
	if !ok {
		return nil, fmt.Errorf("unknown service type: %s", order.ServiceType)
	}

	smOrder := &statemachine.Order{
		ID:     order.ID,
		Status: statemachine.OrderStatus(order.Status),
	}

	event := statemachine.EventCustomerCancelled
	if cancelledBy == "driver" {
		event = statemachine.EventDriverCancelled
	}

	if err := sm.ProcessEvent(smOrder, event); err != nil {
		return nil, fmt.Errorf("cannot cancel: %w", err)
	}

	if err := s.orderRepo.CancelOrder(ctx, orderID, cancelledBy, reason); err != nil {
		return nil, fmt.Errorf("cancel order: %w", err)
	}

	order.Status = string(smOrder.Status)

	// Publish cancellation event
	if s.eventProducer != nil {
		s.eventProducer.PublishAsync(ctx, order.ID, kafka.EventOrderCancelled, kafka.OrderEventData{
			OrderID:      order.ID,
			ServiceType:  order.ServiceType,
			CustomerID:   order.CustomerID,
			CancelledBy:  cancelledBy,
			CancelReason: reason,
			Status:       order.Status,
		})
	}

	return order, nil
}

// ListOrders lists orders for a user
func (s *OrderService) ListOrders(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]model.Order, int, error) {
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

	if role == "driver" {
		return s.orderRepo.ListByDriver(ctx, userID, serviceType, pageSize, offset)
	}
	return s.orderRepo.ListByCustomer(ctx, userID, serviceType, pageSize, offset)
}

// EstimatePrice estimates price for any service type
func (s *OrderService) EstimatePrice(serviceType, vehicleType string, distanceKm float64, durationMin int,
	itemsTotal float64, isDuo, isNight bool, surgeMultiplier float64) PriceBreakdown {

	switch serviceType {
	case "ride":
		return s.pricing.CalculateRideFare(vehicleType, distanceKm, durationMin, surgeMultiplier)
	case "food_delivery":
		return s.pricing.CalculateFoodDeliveryFee(itemsTotal, distanceKm, surgeMultiplier)
	case "grocery":
		return s.pricing.CalculateGroceryFee(itemsTotal, distanceKm)
	case "designated_driver":
		return s.pricing.CalculateDesignatedDriverFare(distanceKm, durationMin, isDuo, isNight)
	default:
		return s.pricing.CalculateRideFare("car", distanceKm, durationMin, 1.0)
	}
}
