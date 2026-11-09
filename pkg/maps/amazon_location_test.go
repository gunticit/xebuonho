package maps

import (
	"context"
	"testing"
)

func TestHaversine(t *testing.T) {
	// HCM Ben Thanh Market: 10.7725, 106.6980
	// Landmark 81: 10.7950, 106.7218
	// Expected straight distance: ~3.5 km
	dist := Haversine(10.7725, 106.6980, 10.7950, 106.7218)
	if dist < 3.0 || dist > 4.5 {
		t.Errorf("Expected Haversine distance ~3.5km, got %.2f km", dist)
	}
}

func TestCalculateFallbackRoute(t *testing.T) {
	client := NewAmazonLocationClient("", "ap-southeast-2", "explore.route", "explore.place", nil)
	res := client.CalculateFallbackRoute(10.7725, 106.6980, 10.7950, 106.7218)

	if !res.IsFallback {
		t.Errorf("Expected fallback=true when no API key provided")
	}

	straightDist := Haversine(10.7725, 106.6980, 10.7950, 106.7218)
	expectedMinRoad := straightDist * 1.30

	if res.DistanceKm < expectedMinRoad {
		t.Errorf("Expected road distance >= %.2f, got %.2f", expectedMinRoad, res.DistanceKm)
	}

	if res.DurationMin < 5 {
		t.Errorf("Expected minimum duration >= 5 mins, got %d", res.DurationMin)
	}
}

func TestCalculateRoute_WithMockFallback(t *testing.T) {
	// With an invalid or unconfigured key, CalculateRoute should gracefully fallback without panic or error
	client := NewAmazonLocationClient("invalid-key", "ap-southeast-2", "explore.route", "explore.place", nil)
	res, err := client.CalculateRoute(context.Background(), 10.7725, 106.6980, 10.7950, 106.7218)

	if err != nil {
		t.Errorf("Expected fallback without error, got %v", err)
	}

	if !res.IsFallback {
		t.Errorf("Expected fallback=true on invalid key")
	}

	if res.DistanceKm <= 0 {
		t.Errorf("Expected positive distance, got %.2f", res.DistanceKm)
	}
}

