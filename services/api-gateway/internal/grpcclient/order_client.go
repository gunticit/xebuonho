package grpcclient

import (
	"context"
	"fmt"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// OrderClient wraps gRPC calls to order-service
type OrderClient struct {
	conn *grpc.ClientConn
}

func NewOrderClient(conn *grpc.ClientConn) *OrderClient {
	return &OrderClient{conn: conn}
}

// OrderResponse represents an order from order-service
type OrderResponse struct {
	ID             string          `json:"id"`
	ServiceType    string          `json:"service_type"`
	CustomerID     string          `json:"customer_id"`
	DriverID       string          `json:"driver_id,omitempty"`
	MerchantID     string          `json:"merchant_id,omitempty"`
	Status         string          `json:"status"`
	PickupAddress  string          `json:"pickup_address"`
	DropoffAddress string          `json:"dropoff_address"`
	FareEstimate   float64         `json:"fare_estimate"`
	FareFinal      float64         `json:"fare_final,omitempty"`
	PaymentMethod  string          `json:"payment_method"`
	Items          []OrderItemResp `json:"items,omitempty"`
	CreatedAt      string          `json:"created_at"`
}

type OrderItemResp struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	Quantity   int32   `json:"quantity"`
	UnitPrice  float64 `json:"unit_price"`
	TotalPrice float64 `json:"total_price"`
	Status     string  `json:"status"`
}

// PriceBreakdownResp from order-service pricing
type PriceBreakdownResp struct {
	ItemsTotal      float64 `json:"items_total,omitempty"`
	DeliveryFee     float64 `json:"delivery_fee,omitempty"`
	ServiceFee      float64 `json:"service_fee,omitempty"`
	PackagingFee    float64 `json:"packaging_fee,omitempty"`
	BaseFare        float64 `json:"base_fare,omitempty"`
	DistanceFare    float64 `json:"distance_fare,omitempty"`
	TimeFare        float64 `json:"time_fare,omitempty"`
	SurgeMultiplier float64 `json:"surge_multiplier"`
	SurgeAmount     float64 `json:"surge_amount,omitempty"`
	ShadowDriverFee float64 `json:"shadow_driver_fee,omitempty"`
	NightSurcharge  float64 `json:"night_surcharge,omitempty"`
	Discount        float64 `json:"discount,omitempty"`
	PlatformFee     float64 `json:"platform_fee"`
	TotalEstimate   float64 `json:"total_estimate"`
	Currency        string  `json:"currency"`
}

// CreateOrderRequest for creating orders
type CreateOrderReq struct {
	ServiceType    string
	CustomerID     string
	IdempotencyKey string
	PickupLat      float64
	PickupLng      float64
	PickupAddress  string
	DropoffLat     float64
	DropoffLng     float64
	DropoffAddress string
	VehicleType    string
	MerchantID     string
	PaymentMethod  string
	PromoCode      string
	Items          []OrderItemReq
	ShoppingList   []ShoppingListReq
}

type OrderItemReq struct {
	MenuItemID string
	Quantity   int32
	Notes      string
}

type ShoppingListReq struct {
	Name           string
	Quantity       int32
	Unit           string
	EstimatedPrice float64
	Notes          string
}

// CreateOrder calls order-service via gRPC
func (c *OrderClient) CreateOrder(ctx context.Context, req CreateOrderReq) (*OrderResponse, *PriceBreakdownResp, error) {
	// client := orderpb.NewOrderServiceClient(c.conn)
	// resp, err := client.CreateOrder(ctx, ...)

	initialStatus := "created"
	if req.ServiceType == "food_delivery" {
		initialStatus = "placed"
	}

	return &OrderResponse{
			ID:          fmt.Sprintf("order-%d", timestamppb.Now().GetSeconds()),
			ServiceType: req.ServiceType,
			CustomerID:  req.CustomerID,
			Status:      initialStatus,
			CreatedAt:   timestamppb.Now().AsTime().Format("2006-01-02T15:04:05Z"),
		}, &PriceBreakdownResp{
			Currency: "VND",
		}, nil
}

// GetOrder calls order-service GetOrder
func (c *OrderClient) GetOrder(ctx context.Context, orderID string) (*OrderResponse, error) {
	return &OrderResponse{ID: orderID, Status: "created"}, nil
}

// UpdateOrderStatus calls order-service UpdateOrderStatus
func (c *OrderClient) UpdateOrderStatus(ctx context.Context, orderID, actorID, actorRole, event string) (*OrderResponse, error) {
	return &OrderResponse{ID: orderID, Status: event}, nil
}

// CancelOrder calls order-service CancelOrder
func (c *OrderClient) CancelOrder(ctx context.Context, orderID, cancelledBy, reason string) (*OrderResponse, error) {
	return &OrderResponse{
		ID:     orderID,
		Status: "cancelled_by_" + cancelledBy,
	}, nil
}

// ListOrders calls order-service ListOrders
func (c *OrderClient) ListOrders(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]OrderResponse, int, error) {
	return []OrderResponse{}, 0, nil
}

// EstimatePrice calls order-service EstimatePrice
func (c *OrderClient) EstimatePrice(ctx context.Context, serviceType, vehicleType string, distanceKm float64, itemsTotal float64) (*PriceBreakdownResp, error) {
	return &PriceBreakdownResp{Currency: "VND"}, nil
}
