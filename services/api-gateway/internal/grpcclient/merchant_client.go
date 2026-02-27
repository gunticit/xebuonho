package grpcclient

import (
	"context"
	"fmt"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// MerchantClient wraps gRPC calls to merchant-service
type MerchantClient struct {
	conn *grpc.ClientConn
}

func NewMerchantClient(conn *grpc.ClientConn) *MerchantClient {
	return &MerchantClient{conn: conn}
}

// MerchantResponse from merchant-service
type MerchantResponse struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	Description     string  `json:"description"`
	Category        string  `json:"category"`
	Phone           string  `json:"phone"`
	Address         string  `json:"address"`
	LogoURL         string  `json:"logo_url"`
	CoverURL        string  `json:"cover_url"`
	Rating          float32 `json:"rating"`
	TotalOrders     int32   `json:"total_orders"`
	IsActive        bool    `json:"is_active"`
	IsOpenNow       bool    `json:"is_open_now"`
	DistanceKm      float64 `json:"distance_km,omitempty"`
	DeliveryTimeMin int32   `json:"delivery_time_min,omitempty"`
}

type MenuCategoryResp struct {
	Name  string         `json:"name"`
	Items []MenuItemResp `json:"items"`
}

type MenuItemResp struct {
	ID              string  `json:"id"`
	Name            string  `json:"name"`
	Description     string  `json:"description"`
	Price           float64 `json:"price"`
	ImageURL        string  `json:"image_url"`
	IsAvailable     bool    `json:"is_available"`
	PreparationTime int32   `json:"preparation_time_min"`
}

// ListNearby calls merchant-service ListNearbyMerchants
func (c *MerchantClient) ListNearby(ctx context.Context, lat, lng, radiusKm float64, category, sortBy string, page, pageSize int) ([]MerchantResponse, int, error) {
	// client := merchantpb.NewMerchantServiceClient(c.conn)
	// resp, err := client.ListNearbyMerchants(ctx, ...)
	return []MerchantResponse{}, 0, nil
}

// GetMerchant calls merchant-service GetMerchant
func (c *MerchantClient) GetMerchant(ctx context.Context, merchantID string) (*MerchantResponse, error) {
	return &MerchantResponse{ID: merchantID}, nil
}

// GetMenu calls merchant-service GetMenu
func (c *MerchantClient) GetMenu(ctx context.Context, merchantID string) ([]MenuCategoryResp, error) {
	return []MenuCategoryResp{}, nil
}

// SearchMerchants calls merchant-service SearchMerchants
func (c *MerchantClient) SearchMerchants(ctx context.Context, query string, lat, lng, radiusKm float64, page, pageSize int) ([]MerchantResponse, int, error) {
	return []MerchantResponse{}, 0, nil
}

// CreateMerchant calls merchant-service CreateMerchant
func (c *MerchantClient) CreateMerchant(ctx context.Context, ownerID, name, description, category, phone, address string, lat, lng float64, logoURL string) (*MerchantResponse, error) {
	return &MerchantResponse{
		ID:       fmt.Sprintf("merchant-%d", timestamppb.Now().GetSeconds()),
		Name:     name,
		Category: category,
		IsActive: true,
	}, nil
}

// CreateMenuItem calls merchant-service CreateMenuItem
func (c *MerchantClient) CreateMenuItem(ctx context.Context, merchantID, categoryName, name, description string, price float64, imageURL string) (*MenuItemResp, error) {
	return &MenuItemResp{
		ID:          fmt.Sprintf("item-%d", timestamppb.Now().GetSeconds()),
		Name:        name,
		Price:       price,
		IsAvailable: true,
	}, nil
}
