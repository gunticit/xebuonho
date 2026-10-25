package main

import (
	"context"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/services/driver-service/internal/config"
	"github.com/xebuonho/services/driver-service/internal/repository"
	"github.com/xebuonho/services/driver-service/internal/service"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
)

// MockMQTTClient implements the MQTTClient interface for demo purposes
type MockMQTTClient struct{}

func (m *MockMQTTClient) Publish(topic string, payload interface{}) error {
	log.Printf("[MQTT-MOCK] Published to %s: %v", topic, payload)
	return nil
}

// RideServiceMock implements the RideServiceClient interface for demo purposes
type RideServiceMock struct{}

func (m *RideServiceMock) UpdateRideStatus(ctx context.Context, rideID, status, driverID string) error {
	log.Printf("[RIDE-SVC-MOCK] Ride %s status updated to %s by driver %s", rideID, status, driverID)
	return nil
}

func main() {
	cfg := config.LoadConfig()
	log.Printf("[%s] Starting Driver Service on HTTP :%s, gRPC :%s...", cfg.ServiceName, cfg.HTTPPort, cfg.GRPCPort)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Database Connection
	db, err := database.ConnectPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect DB: %v", err)
	}
	defer db.Close()

	// 2. Initialize Layers
	repo := repository.NewDriverRepository(db)
	mqtt := &MockMQTTClient{}

	// In real app, this would be a gRPC client connecting to Ride Service
	rideSvcMock := &RideServiceMock{}
	driverSvc := service.NewDriverService(repo, mqtt, rideSvcMock)
	_ = driverSvc

	// 3. gRPC Server
	grpcServer := grpc.NewServer()
	healthServer := health.NewServer()
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)
	healthServer.SetServingStatus(cfg.ServiceName, grpc_health_v1.HealthCheckResponse_SERVING)

	// 4. HTTP Server
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok","service":"driver-service"}`))
	})

	httpServer := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
	}

	go func() {
		lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
		if err != nil {
			log.Fatalf("Failed to listen gRPC: %v", err)
		}
		log.Printf("gRPC server listening on :%s", cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil && err != grpc.ErrServerStopped {
			log.Fatalf("gRPC server failed: %v", err)
		}
	}()

	go func() {
		log.Printf("HTTP server listening on :%s", cfg.HTTPPort)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("HTTP server failed: %v", err)
		}
	}()

	// Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down Driver Service...")
	grpcServer.GracefulStop()
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	_ = httpServer.Shutdown(shutdownCtx)
}
