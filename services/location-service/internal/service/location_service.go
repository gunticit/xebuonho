package service

import (
	"context"
	"fmt"
	"log"

	"github.com/xebuonho/services/location-service/internal/model"
	"github.com/xebuonho/services/location-service/internal/repository"
)

type LocationService interface {
	UpdateLocation(ctx context.Context, update model.LocationUpdate) error
	GetLocation(ctx context.Context, driverID string) (*model.DriverLocation, error)
	GetNearbyDrivers(ctx context.Context, lat, lng, radiusKm float64) ([]string, error)
}

type locationService struct {
	repo       repository.LocationRepository
	wsPublisher WSPublisher
}

// WSPublisher interface for pushing locations to riders via WebSockets
type WSPublisher interface {
	PushLocation(driverID string, location model.DriverLocation) error
}

func NewLocationService(repo repository.LocationRepository, ws WSPublisher) LocationService {
	return &locationService{
		repo:       repo,
		wsPublisher: ws,
	}
}

func (s *locationService) UpdateLocation(ctx context.Context, update model.LocationUpdate) error {
	// Anti-Fraud 1: Bounds validation
	if update.Lat < -90.0 || update.Lat > 90.0 || update.Lng < -180.0 || update.Lng > 180.0 {
		return fmt.Errorf("invalid coordinate bounds")
	}

	// Anti-Fraud 2: Mock GPS Provider Check
	if update.IsMock {
		log.Printf("[anti-fraud] 🚨 MOCK GPS DETECTED from driver %s at [%.4f, %.4f]. Rejected.", update.DriverID, update.Lat, update.Lng)
		return fmt.Errorf("mock location provider rejected by security policy")
	}

	// Anti-Fraud 3: Speed Anomaly Check (> 130 km/h in urban setting)
	if update.Speed > 130.0 {
		log.Printf("[anti-fraud] 🚨 SPEED ANOMALY DETECTED from driver %s: %.1f km/h. Flagged.", update.DriverID, update.Speed)
		return fmt.Errorf("speed anomaly detected: %.1f km/h exceeds legal operating limits", update.Speed)
	}

	// 1. Persist to Redis Geo
	err := s.repo.UpdateDriverLocation(ctx, update.DriverID, update.Lat, update.Lng)
	if err != nil {
		return fmt.Errorf("update location repo: %w", err)
	}

	// 2. Push to WebSocket for real-time tracking
	if s.wsPublisher != nil {
		loc := model.DriverLocation{
			DriverID:  update.DriverID,
			Lat:       update.Lat,
			Lng:       update.Lng,
			Heading:   update.Heading,
			Speed:     update.Speed,
		}
		// In a real system, we would only push to riders who are currently
		// in a ride with this driver.
		if err := s.wsPublisher.PushLocation(update.DriverID, loc); err != nil {
			log.Printf("[location-service] WS push error for driver %s: %v", update.DriverID, err)
		}
	}

	return nil
}

func (s *locationService) GetLocation(ctx context.Context, driverID string) (*model.DriverLocation, error) {
	lat, lng, err := s.repo.GetDriverLocation(ctx, driverID)
	if err != nil {
		return nil, err
	}

	return &model.DriverLocation{
		DriverID: driverID,
		Lat:      lat,
		Lng:      lng,
	}, nil
}

func (s *locationService) GetNearbyDrivers(ctx context.Context, lat, lng, radiusKm float64) ([]string, error) {
	drivers, err := s.repo.GetNearbyDrivers(ctx, lat, lng, radiusKm)
	if err != nil {
		return nil, fmt.Errorf("get nearby drivers: %w", err)
	}
	return drivers, nil
}
