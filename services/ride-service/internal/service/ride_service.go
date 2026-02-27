package service

import (
	"context"
	"fmt"
	"math"

	"github.com/xebuonho/services/ride-service/internal/model"
	"github.com/xebuonho/services/ride-service/internal/repository"
)

// RideService handles ride business logic
type RideService struct {
	rideRepo *repository.RideRepository
}

// NewRideService creates a new ride service
func NewRideService(rideRepo *repository.RideRepository) *RideService {
	return &RideService{rideRepo: rideRepo}
}

// CreateRide creates a new ride request
func (s *RideService) CreateRide(ctx context.Context, riderID string, pickupLat, pickupLng float64, pickupAddr string,
	dropoffLat, dropoffLng float64, dropoffAddr, vehicleType, paymentMethod, promoCode, idempotencyKey string,
) (*model.Ride, *model.FareEstimate, error) {

	if riderID == "" {
		return nil, nil, fmt.Errorf("rider_id is required")
	}
	if idempotencyKey == "" {
		return nil, nil, fmt.Errorf("idempotency_key is required")
	}
	if vehicleType == "" {
		vehicleType = "car"
	}
	if paymentMethod == "" {
		paymentMethod = "cash"
	}

	// Estimate distance & fare
	distanceKm := haversine(pickupLat, pickupLng, dropoffLat, dropoffLng)
	durationMin := estimateDuration(distanceKm)
	fareEst := calculateFare(vehicleType, distanceKm, durationMin, 1.0)

	ride := &model.Ride{
		RiderID:        riderID,
		PickupLat:      pickupLat,
		PickupLng:      pickupLng,
		PickupAddress:  pickupAddr,
		DropoffLat:     dropoffLat,
		DropoffLng:     dropoffLng,
		DropoffAddress: dropoffAddr,
		VehicleType:    vehicleType,
		Status:         "created",
		FareEstimate:   fareEst.TotalFare,
		PaymentMethod:  paymentMethod,
		PromoCode:      promoCode,
		DistanceKm:     distanceKm,
		DurationMin:    durationMin,
		IdempotencyKey: idempotencyKey,
	}

	if err := s.rideRepo.Create(ctx, ride); err != nil {
		return nil, nil, fmt.Errorf("create ride: %w", err)
	}

	return ride, &fareEst, nil
}

// GetRide retrieves a ride by ID
func (s *RideService) GetRide(ctx context.Context, rideID string) (*model.Ride, error) {
	return s.rideRepo.GetByID(ctx, rideID)
}

// ListRides lists rides for a rider
func (s *RideService) ListRides(ctx context.Context, riderID string, page, pageSize int) ([]model.Ride, int, error) {
	if pageSize <= 0 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}
	return s.rideRepo.ListByRider(ctx, riderID, pageSize, offset)
}

// EstimateFare calculates fare estimate
func (s *RideService) EstimateFare(pickupLat, pickupLng, dropoffLat, dropoffLng float64, vehicleType string) model.FareEstimate {
	distanceKm := haversine(pickupLat, pickupLng, dropoffLat, dropoffLng)
	durationMin := estimateDuration(distanceKm)
	return calculateFare(vehicleType, distanceKm, durationMin, 1.0)
}

// haversine calculates the great-circle distance between two points
func haversine(lat1, lng1, lat2, lng2 float64) float64 {
	const R = 6371 // Earth radius in km
	dLat := (lat2 - lat1) * math.Pi / 180
	dLng := (lng2 - lng1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c * 1.3 // ×1.3 for road factor
}

func estimateDuration(distanceKm float64) int {
	avgSpeedKmH := 25.0 // Average speed in city
	return int(math.Ceil(distanceKm / avgSpeedKmH * 60))
}

type fareConfig struct {
	baseFare, tier1Price, tier2Price, tier3Price, pricePerMin, platformFee, minFare float64
	tier1Km, tier2Km                                                                float64
}

var fareConfigs = map[string]fareConfig{
	"bike":    {12000, 5000, 4200, 3800, 300, 2000, 12000, 2, 30},
	"car":     {25000, 12000, 9500, 8500, 500, 3000, 25000, 2, 30},
	"premium": {35000, 16000, 14000, 12000, 800, 5000, 35000, 2, 30},
}

func calculateFare(vehicleType string, distanceKm float64, durationMin int, surge float64) model.FareEstimate {
	cfg, ok := fareConfigs[vehicleType]
	if !ok {
		cfg = fareConfigs["car"]
	}

	var distFare float64
	rem := distanceKm
	if rem > 0 {
		t := math.Min(rem, cfg.tier1Km)
		distFare += t * cfg.tier1Price
		rem -= t
	}
	if rem > 0 {
		t := math.Min(rem, cfg.tier2Km-cfg.tier1Km)
		distFare += t * cfg.tier2Price
		rem -= t
	}
	if rem > 0 {
		distFare += rem * cfg.tier3Price
	}

	timeFare := float64(durationMin) * cfg.pricePerMin
	subtotal := cfg.baseFare + distFare + timeFare
	if surge <= 0 {
		surge = 1.0
	}
	surgeAmt := subtotal * (surge - 1)
	total := subtotal + surgeAmt + cfg.platformFee
	total = math.Max(total, cfg.minFare)
	total = math.Ceil(total/1000) * 1000

	return model.FareEstimate{
		BaseFare:        cfg.baseFare,
		DistanceFare:    distFare,
		TimeFare:        timeFare,
		SurgeMultiplier: surge,
		SurgeAmount:     surgeAmt,
		PlatformFee:     cfg.platformFee,
		TotalFare:       total,
		Currency:        "VND",
	}
}
