package repository

import (
	"context"
	"fmt"
	"github.com/redis/go-redis/v9"
)

type LocationRepository interface {
	UpdateDriverLocation(ctx context.Context, driverID string, lat, lng float64) error
	GetDriverLocation(ctx context.Context, driverID string) (lat, lng float64, err error)
	GetNearbyDrivers(ctx context.Context, lat, lng, radiusKm float64) ([]string, error)
}

type redisLocationRepo struct {
	redis *redis.Client
}

func NewLocationRepository(redis *redis.Client) LocationRepository {
	return &redisLocationRepo{redis: redis}
}

func (r *redisLocationRepo) UpdateDriverLocation(ctx context.Context, driverID string, lat, lng float64) error {
	// Use Redis GEOADD to store location for geospatial queries
	err := r.redis.GeoAdd(ctx, "active_drivers_location", &redis.GeoLocation{
		Name:      driverID,
		Longitude: lng,
		Latitude:  lat,
	}).Err()
	if err != nil {
		return fmt.Errorf("redis geoadd: %w", err)
	}
	return nil
}

func (r *redisLocationRepo) GetDriverLocation(ctx context.Context, driverID string) (lat, lng float64, err error) {
	pos, err := r.redis.GeoPos(ctx, "active_drivers_location", driverID).Result()
	if err != nil {
		return 0, 0, fmt.Errorf("redis geopos: %w", err)
	}
	if len(pos) == 0 {
		return 0, 0, fmt.Errorf("driver location not found")
	}
	return pos[0].Latitude, pos[0].Longitude, nil
}

func (r *redisLocationRepo) GetNearbyDrivers(ctx context.Context, lat, lng, radiusKm float64) ([]string, error) {
	res, err := r.redis.GeoSearch(ctx, "active_drivers_location", &redis.GeoSearchQuery{
		Longitude: lng,
		Latitude:  lat,
		Radius:    radiusKm,
	}).Result()
	if err != nil {
		return nil, fmt.Errorf("redis geosearch: %w", err)
	}
	return res, nil
}
