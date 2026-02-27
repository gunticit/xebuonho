package grpcclient

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/keepalive"
)

// ClientPool manages gRPC connections to backend services
type ClientPool struct {
	conns map[string]*grpc.ClientConn
}

// ServiceAddresses holds addresses for all backend services
type ServiceAddresses struct {
	RideService     string
	OrderService    string
	MerchantService string
}

// NewClientPool creates and connects to all backend services
func NewClientPool(ctx context.Context, addrs ServiceAddresses) (*ClientPool, error) {
	pool := &ClientPool{
		conns: make(map[string]*grpc.ClientConn),
	}

	services := map[string]string{
		"ride":     addrs.RideService,
		"order":    addrs.OrderService,
		"merchant": addrs.MerchantService,
	}

	for name, addr := range services {
		conn, err := dialService(ctx, addr)
		if err != nil {
			pool.Close() // Clean up already opened connections
			return nil, fmt.Errorf("connect to %s at %s: %w", name, addr, err)
		}
		pool.conns[name] = conn
	}

	return pool, nil
}

// GetRideConn returns the ride-service gRPC connection
func (p *ClientPool) GetRideConn() *grpc.ClientConn {
	return p.conns["ride"]
}

// GetOrderConn returns the order-service gRPC connection
func (p *ClientPool) GetOrderConn() *grpc.ClientConn {
	return p.conns["order"]
}

// GetMerchantConn returns the merchant-service gRPC connection
func (p *ClientPool) GetMerchantConn() *grpc.ClientConn {
	return p.conns["merchant"]
}

// Close closes all gRPC connections
func (p *ClientPool) Close() {
	for _, conn := range p.conns {
		if conn != nil {
			conn.Close()
		}
	}
}

func dialService(ctx context.Context, addr string) (*grpc.ClientConn, error) {
	dialCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	return grpc.DialContext(dialCtx, addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithKeepaliveParams(keepalive.ClientParameters{
			Time:                30 * time.Second,
			Timeout:             10 * time.Second,
			PermitWithoutStream: true,
		}),
		grpc.WithDefaultServiceConfig(`{
			"loadBalancingPolicy": "round_robin",
			"methodConfig": [{
				"name": [{"service": ""}],
				"timeout": "10s",
				"retryPolicy": {
					"maxAttempts": 3,
					"initialBackoff": "0.1s",
					"maxBackoff": "1s",
					"backoffMultiplier": 2,
					"retryableStatusCodes": ["UNAVAILABLE", "DEADLINE_EXCEEDED"]
				}
			}]
		}`),
	)
}
