package service_test

import (
	"context"
	"testing"

	"github.com/xebuonho/pkg/statemachine"
	"github.com/xebuonho/services/matching-service/internal/config"
	"github.com/xebuonho/services/matching-service/internal/model"
	"github.com/xebuonho/services/matching-service/internal/service"
)

// mockGeoRepository implements repository.GeoRepository in-memory for testing
type mockGeoRepository struct {
	drivers []model.NearbyDriver
	metaMap map[string]*model.DriverMeta
}

func newMockGeoRepository(drivers []model.NearbyDriver) *mockGeoRepository {
	return &mockGeoRepository{
		drivers: drivers,
		metaMap: make(map[string]*model.DriverMeta),
	}
}

func (m *mockGeoRepository) FindNearby(ctx context.Context, lat, lng float64, radiusKm float64, limit int) ([]model.NearbyDriver, error) {
	var result []model.NearbyDriver
	for _, d := range m.drivers {
		if d.DistanceKm <= radiusKm {
			result = append(result, d)
		}
	}
	return result, nil
}

func (m *mockGeoRepository) GetDriverMeta(ctx context.Context, driverID string) (*model.DriverMeta, error) {
	if meta, ok := m.metaMap[driverID]; ok {
		return meta, nil
	}
	return nil, nil
}

func (m *mockGeoRepository) SetDriverMeta(ctx context.Context, meta *model.DriverMeta) error {
	m.metaMap[meta.DriverID] = meta
	return nil
}

func (m *mockGeoRepository) AddDriverLocation(ctx context.Context, driverID string, lat, lng float64) error {
	m.drivers = append(m.drivers, model.NearbyDriver{
		DriverID:  driverID,
		Latitude:  lat,
		Longitude: lng,
		Status:    "online",
	})
	return nil
}

// Table-driven test for CalculateScore
func TestCalculateScore(t *testing.T) {
	cfg := &config.Config{
		WeightDistance: 0.4,
		WeightRating:   0.3,
		WeightWaitTime: 0.3,
	}
	svc := service.NewMatchingService(newMockGeoRepository(nil), nil, cfg)

	tests := []struct {
		name          string
		driver        model.NearbyDriver
		expectedMin   float64
		expectedMax   float64
		checkRelative func(scoreA, scoreB float64) bool
	}{
		{
			name: "Perfect driver: close, 5.0 rating, 0 wait time",
			driver: model.NearbyDriver{
				DistanceKm:      0.0, // distScore = 1.0 -> 0.4*1.0 = 0.4
				Rating:          5.0, // ratingScore = 1.0 -> 0.3*1.0 = 0.3
				WaitTimeMinutes: 0.0, // waitScore = 1.0 -> 0.3*1.0 = 0.3
			},
			expectedMin: 0.99,
			expectedMax: 1.01,
		},
		{
			name: "Far driver: 9km, 3.0 rating, 9 min wait",
			driver: model.NearbyDriver{
				DistanceKm:      9.0, // distScore = 0.1 -> 0.04
				Rating:          3.0, // ratingScore = 0.6 -> 0.18
				WaitTimeMinutes: 9.0, // waitScore = 0.1 -> 0.03
			},
			expectedMin: 0.20,
			expectedMax: 0.30,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			score := svc.CalculateScore(tt.driver)
			if score < tt.expectedMin || score > tt.expectedMax {
				t.Errorf("CalculateScore() = %v, want between %v and %v", score, tt.expectedMin, tt.expectedMax)
			}
		})
	}
}

// Table-driven test for Driver Ranking
func TestDriverRankingOrder(t *testing.T) {
	cfg := &config.Config{
		InitialRadiusKm:  2.0,
		FallbackRadiusKm: 5.0,
		WeightDistance:   0.5,
		WeightRating:     0.3,
		WeightWaitTime:   0.2,
	}

	drivers := []model.NearbyDriver{
		{
			DriverID:        "driver-far-lowrating",
			DistanceKm:      1.8,
			Rating:          4.0,
			WaitTimeMinutes: 5.0,
			Status:          "online",
			Capabilities:    []string{"ride"},
		},
		{
			DriverID:        "driver-closest-highrating",
			DistanceKm:      0.3,
			Rating:          4.9,
			WaitTimeMinutes: 1.0,
			Status:          "online",
			Capabilities:    []string{"ride"},
		},
	}

	repo := newMockGeoRepository(drivers)
	svc := service.NewMatchingService(repo, nil, cfg)

	req := model.MatchRequest{
		OrderID:     "order-101",
		ServiceType: "ride",
		PickupLat:   10.7769,
		PickupLng:   106.7009,
	}

	res, err := svc.MatchDriver(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.Status != string(statemachine.StatusDriverAssigned) {
		t.Fatalf("expected status %s, got %s", statemachine.StatusDriverAssigned, res.Status)
	}

	if res.MatchedDriver == nil || res.MatchedDriver.DriverID != "driver-closest-highrating" {
		t.Fatalf("expected matched driver 'driver-closest-highrating', got %+v", res.MatchedDriver)
	}
}

// Table-driven test for Radius Fallback: 2km -> 5km
func TestMatchDriver_FallbackExpansion(t *testing.T) {
	cfg := &config.Config{
		InitialRadiusKm:  2.0,
		FallbackRadiusKm: 5.0,
		WeightDistance:   0.4,
		WeightRating:     0.3,
		WeightWaitTime:   0.3,
	}

	// Driver is at 3.5 km (beyond 2km, but within 5km)
	drivers := []model.NearbyDriver{
		{
			DriverID:        "driver-in-fallback-range",
			DistanceKm:      3.5,
			Rating:          4.8,
			WaitTimeMinutes: 2.0,
			Status:          "online",
			Capabilities:    []string{"ride"},
		},
	}

	repo := newMockGeoRepository(drivers)
	svc := service.NewMatchingService(repo, nil, cfg)

	req := model.MatchRequest{
		OrderID:     "order-fallback-test",
		ServiceType: "ride",
		PickupLat:   10.7769,
		PickupLng:   106.7009,
	}

	res, err := svc.MatchDriver(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.Status != string(statemachine.StatusDriverAssigned) {
		t.Fatalf("expected status %s, got %s", statemachine.StatusDriverAssigned, res.Status)
	}

	if res.SearchRadiusKm != 5.0 {
		t.Errorf("expected expanded search radius 5.0, got %v", res.SearchRadiusKm)
	}

	if res.MatchedDriver == nil || res.MatchedDriver.DriverID != "driver-in-fallback-range" {
		t.Errorf("expected matched driver 'driver-in-fallback-range', got %+v", res.MatchedDriver)
	}
}

// Test when no driver is available in both 2km and 5km
func TestMatchDriver_NoDriverAvailable(t *testing.T) {
	cfg := &config.Config{
		InitialRadiusKm:  2.0,
		FallbackRadiusKm: 5.0,
		WeightDistance:   0.4,
		WeightRating:     0.3,
		WeightWaitTime:   0.3,
	}

	// Driver is 10km away (beyond 5km)
	drivers := []model.NearbyDriver{
		{
			DriverID:     "driver-far-away",
			DistanceKm:   10.0,
			Rating:       5.0,
			Status:       "online",
			Capabilities: []string{"ride"},
		},
	}

	repo := newMockGeoRepository(drivers)
	svc := service.NewMatchingService(repo, nil, cfg)

	req := model.MatchRequest{
		OrderID:     "order-no-driver",
		ServiceType: "ride",
		PickupLat:   10.7769,
		PickupLng:   106.7009,
	}

	res, err := svc.MatchDriver(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.Status != string(statemachine.StatusNoDriver) {
		t.Fatalf("expected status %s, got %s", statemachine.StatusNoDriver, res.Status)
	}

	if res.MatchedDriver != nil {
		t.Errorf("expected MatchedDriver to be nil, got %+v", res.MatchedDriver)
	}
}

// Test service capability filtering (e.g. food delivery vs designated driver)
func TestMatchDriver_CapabilityFiltering(t *testing.T) {
	cfg := &config.Config{
		InitialRadiusKm:  2.0,
		FallbackRadiusKm: 5.0,
		WeightDistance:   0.4,
		WeightRating:     0.3,
		WeightWaitTime:   0.3,
	}

	drivers := []model.NearbyDriver{
		{
			DriverID:     "driver-ride-only",
			DistanceKm:   0.5,
			Rating:       5.0,
			Status:       "online",
			Capabilities: []string{"ride"},
		},
		{
			DriverID:     "driver-food-capable",
			DistanceKm:   1.0,
			Rating:       4.8,
			Status:       "online",
			Capabilities: []string{"food", "grocery"},
		},
	}

	repo := newMockGeoRepository(drivers)
	svc := service.NewMatchingService(repo, nil, cfg)

	req := model.MatchRequest{
		OrderID:     "order-food-test",
		ServiceType: "food",
		PickupLat:   10.7769,
		PickupLng:   106.7009,
	}

	res, err := svc.MatchDriver(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if res.MatchedDriver == nil || res.MatchedDriver.DriverID != "driver-food-capable" {
		t.Fatalf("expected 'driver-food-capable', got %+v", res.MatchedDriver)
	}
}
