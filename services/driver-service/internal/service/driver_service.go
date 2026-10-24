package service

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/xebuonho/pkg/kafka"
	"github.com/xebuonho/services/driver-service/internal/model"
	"github.com/xebuonho/services/driver-service/internal/repository"
)

type RideServiceClient interface {
	UpdateRideStatus(ctx context.Context, rideID, status, driverID string) error
}

type DriverService interface {
	HandleRideAssignment(ctx context.Context, event kafka.OrderEventData) error
	UpdateDriverStatus(ctx context.Context, driverID, status string) error
	AcceptRide(ctx context.Context, driverID, rideID string) error
}

type driverService struct {
	repo           repository.DriverRepository
	mqttPub        MQTTClient
	rideServiceClient RideServiceClient
}

// MQTTClient interface for pushing notifications to drivers
type MQTTClient interface {
	Publish(topic string, payload interface{}) error
}

func NewDriverService(repo repository.DriverRepository, mqtt MQTTClient, rideSvc RideServiceClient) DriverService {
	return &driverService{
		repo:              repo,
		mqttPub:           mqtt,
		rideServiceClient: rideSvc,
	}
}

func (s *driverService) UpdateDriverStatus(ctx context.Context, driverID, status string) error {
	return s.repo.UpdateStatus(ctx, driverID, status)
}

func (s *driverService) HandleRideAssignment(ctx context.Context, event kafka.OrderEventData) error {
	if event.DriverID == "" {
		return fmt.Errorf("no driver assigned in event")
	}

	log.Printf("[driver-service] Notifying driver %s about ride %s", event.DriverID, event.OrderID)

	notification := model.RideNotification{
		RideID:       event.OrderID,
		PickupAddr:   "Loading from RideService...",
		DropoffAddr:  "Loading from RideService...",
		FareEstimate: 0,
		VehicleType:  event.ServiceType,
	}

	payload, _ := json.Marshal(notification)
	topic := fmt.Sprintf("drivers/%s/requests", event.DriverID)

	if s.mqttPub != nil {
		return s.mqttPub.Publish(topic, payload)
	}

	return fmt.Errorf("MQTT publisher not configured")
}

func (s *driverService) AcceptRide(ctx context.Context, driverID, rideID string) error {
	log.Printf("[driver-service] Driver %s accepted ride %s", driverID, rideID)

	// 1. Update driver status to busy
	if err := s.repo.UpdateStatus(ctx, driverID, "busy"); err != nil {
		return fmt.Errorf("update driver status: %w", err)
	}

	// 2. Call Ride Service to update ride status to DRIVER_ARRIVING
	if s.rideServiceClient != nil {
		err := s.rideServiceClient.UpdateRideStatus(ctx, rideID, "driver_arriving", driverID)
		if err != nil {
			return fmt.Errorf("update ride status: %w", err)
		}
	}

	return nil
}
