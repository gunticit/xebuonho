package repository

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/redis/go-redis/v9"
	"github.com/xebuonho/services/matching-service/internal/model"
)

// GeoRepository defines interface for querying driver geospatial data
type GeoRepository interface {
	FindNearby(ctx context.Context, lat, lng float64, radiusKm float64, limit int) ([]model.NearbyDriver, error)
	GetDriverMeta(ctx context.Context, driverID string) (*model.DriverMeta, error)
	SetDriverMeta(ctx context.Context, meta *model.DriverMeta) error
	AddDriverLocation(ctx context.Context, driverID string, lat, lng float64) error
}

// RedisGeoRepository implements GeoRepository using Redis
type RedisGeoRepository struct {
	client *redis.Client
}

// NewRedisGeoRepository creates a new RedisGeoRepository
func NewRedisGeoRepository(client *redis.Client) *RedisGeoRepository {
	return &RedisGeoRepository{client: client}
}

// FindNearby searches for drivers near given coordinates within radiusKm
func (r *RedisGeoRepository) FindNearby(ctx context.Context, lat, lng float64, radiusKm float64, limit int) ([]model.NearbyDriver, error) {
	if limit <= 0 {
		limit = 20
	}

	// Try driver:geo first, fallback to drivers:geo:sgn if empty
	geoKeys := []string{"driver:geo", "drivers:geo:sgn"}
	var locations []redis.GeoLocation

	for _, key := range geoKeys {
		// Redis 6.2+ GEOSEARCH
		query := &redis.GeoSearchLocationQuery{
			GeoSearchQuery: redis.GeoSearchQuery{
				Longitude:  lng,
				Latitude:   lat,
				Radius:     radiusKm,
				RadiusUnit: "km",
				Sort:       "asc",
				Count:      limit,
			},
			WithCoord: true,
			WithDist:  true,
		}

		res, err := r.client.GeoSearchLocation(ctx, key, query).Result()
		if err == nil && len(res) > 0 {
			locations = res
			break
		}

		// Fallback for older Redis versions
		radiusRes, errRadius := r.client.GeoRadius(ctx, key, lng, lat, &redis.GeoRadiusQuery{
			Radius:    radiusKm,
			Unit:      "km",
			WithCoord: true,
			WithDist:  true,
			Sort:      "ASC",
			Count:     limit,
		}).Result()
		if errRadius == nil && len(radiusRes) > 0 {
			locations = radiusRes
			break
		}
	}

	drivers := make([]model.NearbyDriver, 0, len(locations))
	for _, loc := range locations {
		driverID := loc.Name
		// Clean prefix if stored as "driver:<id>"
		driverID = strings.TrimPrefix(driverID, "driver:")

		driver := model.NearbyDriver{
			DriverID:   driverID,
			Latitude:   loc.Latitude,
			Longitude:  loc.Longitude,
			DistanceKm: loc.Dist,
			Rating:     5.0, // Default rating if meta not found
			Status:     "online",
		}

		// Calculate approximate ETA (assuming 30 km/h average city speed -> 0.5 km/min)
		driver.ETAMinutes = (loc.Dist / 30.0) * 60.0
		if driver.ETAMinutes < 1.0 {
			driver.ETAMinutes = 1.0
		}

		// Fetch metadata from driver:{id}:meta
		meta, err := r.GetDriverMeta(ctx, driverID)
		if err == nil && meta != nil {
			driver.Rating = meta.Rating
			driver.Status = meta.Status
			driver.Capabilities = meta.Capabilities
			driver.VehicleType = meta.VehicleType
			driver.WaitTimeMinutes = meta.WaitTimeMinutes
		}

		drivers = append(drivers, driver)
	}

	return drivers, nil
}

// GetDriverMeta retrieves metadata hash driver:{id}:meta from Redis
func (r *RedisGeoRepository) GetDriverMeta(ctx context.Context, driverID string) (*model.DriverMeta, error) {
	key := fmt.Sprintf("driver:%s:meta", driverID)
	data, err := r.client.HGetAll(ctx, key).Result()
	if err != nil {
		return nil, fmt.Errorf("hgetall driver meta: %w", err)
	}
	if len(data) == 0 {
		return nil, nil
	}

	meta := &model.DriverMeta{
		DriverID:    driverID,
		Status:      data["status"],
		VehicleType: data["vehicle_type"],
	}

	if val, ok := data["rating"]; ok {
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			meta.Rating = f
		}
	} else {
		meta.Rating = 5.0
	}

	if val, ok := data["wait_time_minutes"]; ok {
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			meta.WaitTimeMinutes = f
		}
	}

	if val, ok := data["capabilities"]; ok && val != "" {
		meta.Capabilities = strings.Split(val, ",")
	}

	return meta, nil
}

// SetDriverMeta sets metadata hash driver:{id}:meta in Redis
func (r *RedisGeoRepository) SetDriverMeta(ctx context.Context, meta *model.DriverMeta) error {
	key := fmt.Sprintf("driver:%s:meta", meta.DriverID)
	fields := map[string]interface{}{
		"status":            meta.Status,
		"rating":            meta.Rating,
		"vehicle_type":      meta.VehicleType,
		"capabilities":      strings.Join(meta.Capabilities, ","),
		"wait_time_minutes": meta.WaitTimeMinutes,
	}

	if err := r.client.HSet(ctx, key, fields).Err(); err != nil {
		return fmt.Errorf("hset driver meta: %w", err)
	}
	return nil
}

// AddDriverLocation adds or updates driver position in driver:geo
func (r *RedisGeoRepository) AddDriverLocation(ctx context.Context, driverID string, lat, lng float64) error {
	// Add to driver:geo
	err := r.client.GeoAdd(ctx, "driver:geo", &redis.GeoLocation{
		Name:      driverID,
		Longitude: lng,
		Latitude:  lat,
	}).Err()
	if err != nil {
		return fmt.Errorf("geoadd driver location: %w", err)
	}
	return nil
}
