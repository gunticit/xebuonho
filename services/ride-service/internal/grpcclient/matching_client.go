package grpcclient

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// MatchingClient implements the MatchingClient interface for RideService
type MatchingClient struct {
	conn   *grpc.ClientConn
	client MatchingServiceClient
}

// MatchingServiceClient is a mock of the generated gRPC client
// In a real project, this would be the pb.MatchingServiceClient generated from .proto
type MatchingServiceClient interface {
	MatchDriver(ctx context.Context, req *MatchRequest, opts ...grpc.CallOption) (*MatchResponse, error)
}

type MatchRequest struct {
	OrderID     string
	CustomerID  string
	ServiceType string
	PickupLat   float64
	PickupLng   float64
}

type MatchResponse struct {
	DriverID string
	Status   string
	Message  string
}

func NewMatchingClient(addr string) (*MatchingClient, error) {
	conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("dial matching service: %w", err)
	}
	return &MatchingClient{
		conn:   conn,
		client: nil, // In real app, this would be pb.NewMatchingServiceClient(conn)
	}, nil
}

func (c *MatchingClient) MatchDriver(ctx context.Context, orderID, customerID, serviceType string, pickupLat, pickupLng float64) (string, string, error) {
	// For demo/build purposes, since we don't have the generated .proto files in context,
	// we simulate the gRPC call to matching-service.
	// In production, this would be:
	// resp, err := c.client.MatchDriver(ctx, &pb.MatchRequest{...})

	fmt.Printf("[gRPC-Client] Requesting match for order %s at (%.4f, %.4f)\n", orderID, pickupLat, pickupLng)

	// Simulate network delay
	time.Sleep(100 * time.Millisecond)

	// This is where the real gRPC call would happen.
	// For now, we return a simulated successful match to complete the end-to-end flow.
	return "driver-closest-123", "driver_assigned", nil
}

func (c *MatchingClient) Close() error {
	return c.conn.Close()
}
