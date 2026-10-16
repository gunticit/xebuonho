package service

import (
	"context"
	"fmt"
	"log"
	"sort"
	"strings"

	"github.com/xebuonho/pkg/kafka"
	"github.com/xebuonho/pkg/statemachine"
	"github.com/xebuonho/services/matching-service/internal/config"
	"github.com/xebuonho/services/matching-service/internal/model"
	"github.com/xebuonho/services/matching-service/internal/repository"
)

// MatchingService defines business logic for finding and assigning drivers
type MatchingService interface {
	FindNearbyDrivers(ctx context.Context, lat, lng float64, radiusKm float64, serviceType string, limit int) ([]model.NearbyDriver, error)
	MatchDriver(ctx context.Context, req model.MatchRequest) (*model.MatchResponse, error)
	CalculateScore(driver model.NearbyDriver) float64
}

type matchingService struct {
	geoRepo  repository.GeoRepository
	producer *kafka.Producer
	cfg      *config.Config
}

// NewMatchingService creates a new MatchingService instance
func NewMatchingService(geoRepo repository.GeoRepository, producer *kafka.Producer, cfg *config.Config) MatchingService {
	return &matchingService{
		geoRepo:  geoRepo,
		producer: producer,
		cfg:      cfg,
	}
}

// CalculateScore computes matching score: higher is better
// score = w1 * distance_score + w2 * rating_score + w3 * wait_time_score
func (s *matchingService) CalculateScore(driver model.NearbyDriver) float64 {
	// Closer distance -> higher score (normalized 0 to 1)
	distScore := 1.0 / (1.0 + driver.DistanceKm)

	// Rating normalized to [0, 1]
	rating := driver.Rating
	if rating > 5.0 {
		rating = 5.0
	}
	if rating < 0 {
		rating = 0
	}
	ratingScore := rating / 5.0

	// Shorter wait time -> higher score (normalized 0 to 1)
	waitScore := 1.0 / (1.0 + driver.WaitTimeMinutes)

	wDist := s.cfg.WeightDistance
	wRating := s.cfg.WeightRating
	wWait := s.cfg.WeightWaitTime

	// Total score
	score := (wDist * distScore) + (wRating * ratingScore) + (wWait * waitScore)
	return score
}

// FindNearbyDrivers discovers and scores available drivers in the vicinity
func (s *matchingService) FindNearbyDrivers(ctx context.Context, lat, lng float64, radiusKm float64, serviceType string, limit int) ([]model.NearbyDriver, error) {
	if radiusKm <= 0 {
		radiusKm = s.cfg.InitialRadiusKm
	}
	if limit <= 0 {
		limit = 10
	}

	drivers, err := s.geoRepo.FindNearby(ctx, lat, lng, radiusKm, limit*2)
	if err != nil {
		return nil, fmt.Errorf("find nearby drivers: %w", err)
	}

	// Filter and score candidates
	candidates := make([]model.NearbyDriver, 0, len(drivers))
	for _, d := range drivers {
		// Only select online drivers
		if d.Status != "" && d.Status != "online" {
			continue
		}

		// Filter by service capability if requested
		if serviceType != "" && len(d.Capabilities) > 0 {
			if !hasCapability(d.Capabilities, serviceType) {
				continue
			}
		}

		d.Score = s.CalculateScore(d)
		candidates = append(candidates, d)
	}

	// Sort candidates descending by score (best driver first)
	sort.Slice(candidates, func(i, j int) bool {
		return candidates[i].Score > candidates[j].Score
	})

	if len(candidates) > limit {
		candidates = candidates[:limit]
	}

	return candidates, nil
}

// MatchDriver attempts to match the best available driver for an order
// Implements 2km initial radius -> 5km fallback radius expansion
func (s *matchingService) MatchDriver(ctx context.Context, req model.MatchRequest) (*model.MatchResponse, error) {
	initialRadius := s.cfg.InitialRadiusKm
	fallbackRadius := s.cfg.FallbackRadiusKm
	if req.PreferredRadiusKm > 0 {
		initialRadius = req.PreferredRadiusKm
	}

	// Step 1: Search in initial radius (2.0 km)
	candidates, err := s.FindNearbyDrivers(ctx, req.PickupLat, req.PickupLng, initialRadius, req.ServiceType, 10)
	if err != nil {
		return nil, fmt.Errorf("initial search nearby drivers: %w", err)
	}

	currentRadius := initialRadius

	// Step 2: Fallback retry with expanded radius (5.0 km) if no driver found
	if len(candidates) == 0 && fallbackRadius > initialRadius {
		log.Printf("[matching-service] No driver found in %.1f km for order %s. Expanding to %.1f km...",
			initialRadius, req.OrderID, fallbackRadius)

		expandedCandidates, err := s.FindNearbyDrivers(ctx, req.PickupLat, req.PickupLng, fallbackRadius, req.ServiceType, 10)
		if err != nil {
			return nil, fmt.Errorf("fallback search nearby drivers: %w", err)
		}
		candidates = expandedCandidates
		currentRadius = fallbackRadius
	}

	// Step 3: Handle no driver available
	if len(candidates) == 0 {
		log.Printf("[matching-service] Order %s: StatusNoDriver after searching up to %.1f km",
			req.OrderID, currentRadius)

		// Emit StatusNoDriver event to Kafka
		if s.producer != nil && req.OrderID != "" {
			eventData := kafka.OrderEventData{
				OrderID:     req.OrderID,
				ServiceType: req.ServiceType,
				CustomerID:  req.CustomerID,
				Status:      string(statemachine.StatusNoDriver),
			}
			_ = s.producer.Publish(ctx, req.OrderID, kafka.EventOrderStatusChanged, eventData)
		}

		return &model.MatchResponse{
			OrderID:         req.OrderID,
			MatchedDriver:   nil,
			SearchRadiusKm:  currentRadius,
			Status:          string(statemachine.StatusNoDriver),
			CandidatesFound: 0,
			Message:         fmt.Sprintf("Không tìm thấy tài xế trong bán kính %.1f km", currentRadius),
		}, nil
	}

	// Step 4: Pick the best driver (highest score)
	bestDriver := candidates[0]
	log.Printf("[matching-service] Order %s matched with driver %s (score: %.3f, dist: %.2f km)",
		req.OrderID, bestDriver.DriverID, bestDriver.Score, bestDriver.DistanceKm)

	// Emit driver assigned event if producer available
	if s.producer != nil && req.OrderID != "" {
		eventData := kafka.OrderEventData{
			OrderID:     req.OrderID,
			ServiceType: req.ServiceType,
			CustomerID:  req.CustomerID,
			DriverID:    bestDriver.DriverID,
			Status:      string(statemachine.StatusDriverAssigned),
		}
		_ = s.producer.Publish(ctx, req.OrderID, kafka.EventOrderDriverAssigned, eventData)
	}

	return &model.MatchResponse{
		OrderID:         req.OrderID,
		MatchedDriver:   &bestDriver,
		SearchRadiusKm:  currentRadius,
		Status:          string(statemachine.StatusDriverAssigned),
		CandidatesFound: len(candidates),
		Message:         "Tìm thấy tài xế phù hợp nhất",
	}, nil
}

func hasCapability(capabilities []string, serviceType string) bool {
	for _, cap := range capabilities {
		if strings.EqualFold(strings.TrimSpace(cap), serviceType) {
			return true
		}
	}
	return false
}
