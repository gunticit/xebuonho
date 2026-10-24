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
