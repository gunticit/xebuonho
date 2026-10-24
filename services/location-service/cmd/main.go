package main

import (
	"context"
	"encoding/json"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/services/location-service/internal/config"
	"github.com/xebuonho/services/location-service/internal/model"
	"github.com/xebuonho/services/location-service/internal/repository"
	"github.com/xebuonho/services/location-service/internal/service"
	"google.golang.org/grpc"
)

// MockWSPublisher simulates pushing locations to riders via WebSockets
type MockWSPublisher struct{}

func (m *MockWSPublisher) PushLocation(driverID string, location model.DriverLocation) error {
	log.Printf("[WS-MOCK] Pushing location to rider: Driver %s is at (%.6f, %.6f) heading %.1f",
		driverID, location.Lat, location.Lng, location.Heading)
	return nil
}

func main() {
	cfg := config.LoadConfig()
	log.Printf("[%s] Starting Location Service...", cfg.ServiceName)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Connect Redis (Critical for GEO storage)
	redisClient, err := database.ConnectRedis(ctx, cfg.RedisURL)
	if err != nil {
		log.Fatalf("Failed to connect Redis: %v", err)
	}

	// 2. Initialize Architecture Layers
	repo := repository.NewLocationRepository(redisClient)
	wsPub := &MockWSPublisher{}
	locationSvc := service.NewLocationService(repo, wsPub)

	// 3. MQTT Consumer for Driver Location Updates
	// In a real implementation, we use an MQTT client (like paho.mqtt.golang)
	go func() {
		log.Println("[location-service] MQTT Subscriber started on topic: locations/updates...")
		// Simulating incoming MQTT messages every 5 seconds for a demo driver
		ticker := time.NewTicker(5 * time.Second)
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				mockUpdate := model.LocationUpdate{
					DriverID: "driver-123",
					Lat:      10.7769, // Example: HCMC
					Lng:      106.7009,
					Heading:  90.0,
					Speed:    30.5,
				}
				log.Printf("[MQTT-IN] Received update for %s", mockUpdate.DriverID)
				if err := locationSvc.UpdateLocation(ctx, mockUpdate); err != nil {
					log.Printf("Error updating location: %v", err)
				}
			}
		}
	}()

	// 4. gRPC Server for internal location queries
	grpcServer := grpc.NewServer()
	// Registration of handlers would go here

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

	// 5. HTTP Health Check
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	go func() {
		log.Printf("HTTP health check listening on :%s", cfg.HTTPPort)
		if err := http.ListenAndServe(":"+cfg.HTTPPort, nil); err != nil {
			log.Printf("HTTP server error: %v", err)
		}
	}()

	// Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down Location Service...")
	grpcServer.GracefulStop()
}
