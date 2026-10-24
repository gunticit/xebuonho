package main

import (
	"context"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/pkg/kafka"
	"github.com/xebuonho/services/driver-service/internal/config"
	"github.com/xebuonho/services/driver-service/internal/repository"
	"github.com/xebuonho/services/driver-service/internal/service"
	"google.golang.org/grpc"
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
	log.Printf("[%s] Starting Driver Service...", cfg.ServiceName)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Database Connection
	db, err := database.ConnectPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect DB: %v", err)
	}

	// 2. Initialize Layers
	repo := repository.NewDriverRepository(db)
	mqtt := &MockMQTTClient{}

	// In real app, this would be a gRPC client connecting to Ride Service
	rideSvcMock := &RideServiceMock{}
	driverSvc := service.NewDriverService(repo, mqtt, rideSvcMock)

	// 3. Start Kafka Consumer for Ride Assignment
	if cfg.KafkaBrokers != "" {
		consumer := kafka.NewConsumer([]string{cfg.KafkaBrokers}, kafka.TopicOrderEvents)
		go func() {
			log.Println("[driver-service] Kafka consumer started...")
			consumer.Consume(ctx, func(event kafka.Event) {
				if event.Type == kafka.EventOrderDriverAssigned {
					var data kafka.OrderEventData
					// Assuming event.Payload is JSON
					// json.Unmarshal(event.Payload, &data)
					log.Printf("[driver-service] Received Driver Assigned event: %s", event.ID)
					_ = driverSvc.HandleRideAssignment(ctx, data)
				}
			})
		}()
	}

	// 4. gRPC Server (for status updates)
	grpcServer := grpc.NewServer()
	// Register handlers here later

	go func() {
		lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
		if err != nil {
			log.Fatalf("Failed to listen gRPC: %v", err)
		}
		log.Printf("gRPC server listening on :%s", cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("gRPC server failed: %v", err)
		}
	}()

	// Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down Driver Service...")
	grpcServer.GracefulStop()
}
