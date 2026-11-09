package maps

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	// UrbanTortuosityFactor: in VN urban areas (HCM, Hanoi), real road distance
	// is typically 1.30 to 1.40 times the straight-line Haversine distance.
	UrbanTortuosityFactor = 1.35
	DefaultAvgSpeedKmH    = 25.0 // Average motorbike/car speed in congested traffic
)

// RouteResult represents the distance, duration, and geometry for a route
type RouteResult struct {
	DistanceKm  float64   `json:"distance_km"`
	DurationMin int       `json:"duration_min"`
	IsFallback  bool      `json:"is_fallback"`
	Source      string    `json:"source"`
	Polyline    string    `json:"polyline,omitempty"`
	Points      [][]float64 `json:"points,omitempty"`
}

// PlaceResult represents a geocoded place from Amazon Location
type PlaceResult struct {
	Label       string  `json:"label"`
	Lat         float64 `json:"lat"`
	Lng         float64 `json:"lng"`
	Country     string  `json:"country,omitempty"`
	SubRegion   string  `json:"sub_region,omitempty"`
}

// AmazonLocationClient handles requests to AWS Location Service APIs
type AmazonLocationClient struct {
	apiKey          string
	region          string
	routeCalculator string
	placeIndex      string
	httpClient      *http.Client
	redisClient     *redis.Client
}

// NewAmazonLocationClient creates a new client using specified credentials
func NewAmazonLocationClient(apiKey, region, routeCalculator, placeIndex string, redisClient *redis.Client) *AmazonLocationClient {
	if region == "" {
		region = "ap-southeast-2"
	}
	if routeCalculator == "" {
		routeCalculator = "explore.route"
	}
	if placeIndex == "" {
		placeIndex = "explore.place"
	}

	return &AmazonLocationClient{
		apiKey:          apiKey,
		region:          region,
		routeCalculator: routeCalculator,
		placeIndex:      placeIndex,
		httpClient: &http.Client{
			Timeout: 5 * time.Second,
		},
		redisClient: redisClient,
	}
}

// NewClientFromEnv initializes the client from environment variables
func NewClientFromEnv(redisClient *redis.Client) *AmazonLocationClient {
	apiKey := os.Getenv("AWS_LOCATION_API_KEY")
	region := os.Getenv("AWS_LOCATION_REGION")
	routeCalc := os.Getenv("AWS_LOCATION_ROUTE_CALCULATOR")
	placeIndex := os.Getenv("AWS_LOCATION_PLACE_INDEX")

	return NewAmazonLocationClient(apiKey, region, routeCalc, placeIndex, redisClient)
}

// CalculateRoute calculates actual driving distance and duration
func (c *AmazonLocationClient) CalculateRoute(ctx context.Context, pickupLat, pickupLng, dropoffLat, dropoffLng float64) (RouteResult, error) {
	// 1. Check Redis cache first (TTL 15 min) to avoid duplicate API calls
	cacheKey := fmt.Sprintf("route:cache:%.4f,%.4f:%.4f,%.4f", pickupLat, pickupLng, dropoffLat, dropoffLng)
	if c.redisClient != nil {
		if cached, err := c.redisClient.Get(ctx, cacheKey).Result(); err == nil && cached != "" {
			var res RouteResult
			if json.Unmarshal([]byte(cached), &res) == nil {
				return res, nil
			}
		}
	}

	// 2. Try Amazon Location Service Route Calculator if API key is set
	if c.apiKey != "" {
		res, err := c.callAWSComputeRoute(ctx, pickupLat, pickupLng, dropoffLat, dropoffLng)
		if err == nil && res.DistanceKm > 0 {
			// Save to cache
			if c.redisClient != nil {
				if data, mErr := json.Marshal(res); mErr == nil {
					_ = c.redisClient.Set(ctx, cacheKey, string(data), 15*time.Minute).Err()
				}
			}
			return res, nil
		}
		log.Printf("[maps] AWS Location Route Calculator error or unauthorized: %v. Using Tortuosity Fallback.", err)
	}

	// 3. Fallback: PostGIS/Haversine distance with Urban Tortuosity Factor (1.35)
	fallbackRes := c.CalculateFallbackRoute(pickupLat, pickupLng, dropoffLat, dropoffLng)
	return fallbackRes, nil
}

func (c *AmazonLocationClient) callAWSComputeRoute(ctx context.Context, pickupLat, pickupLng, dropoffLat, dropoffLng float64) (RouteResult, error) {
	url := fmt.Sprintf(
		"https://routes.geo.%s.amazonaws.com/routes/v0/calculators/%s/calculate/route?key=%s",
		c.region, c.routeCalculator, c.apiKey,
	)

	payload := map[string]interface{}{
		"DeparturePosition":   []float64{pickupLng, pickupLat}, // GeoJSON format: [lng, lat]
		"DestinationPosition": []float64{dropoffLng, dropoffLat},
		"TravelMode":          "Car",
		"IncludeLegGeometry":  true,
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return RouteResult{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return RouteResult{}, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return RouteResult{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return RouteResult{}, fmt.Errorf("aws location routes returned status %d", resp.StatusCode)
	}

	var awsResp struct {
		Summary struct {
			Distance        float64 `json:"Distance"`        // in Kilometers
			DurationSeconds float64 `json:"DurationSeconds"` // in Seconds
		} `json:"Summary"`
		Legs []struct {
			Geometry struct {
				LineString [][]float64 `json:"LineString"`
			} `json:"Geometry"`
		} `json:"Legs"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&awsResp); err != nil {
		return RouteResult{}, err
	}

	durMin := int(math.Ceil(awsResp.Summary.DurationSeconds / 60.0))
	if durMin < 5 {
		durMin = 5
	}

	res := RouteResult{
		DistanceKm:  awsResp.Summary.Distance,
		DurationMin: durMin,
		IsFallback:  false,
		Source:      "amazon_location",
	}

	if len(awsResp.Legs) > 0 && len(awsResp.Legs[0].Geometry.LineString) > 0 {
		res.Points = awsResp.Legs[0].Geometry.LineString
	}

	return res, nil
}

// CalculateFallbackRoute computes estimated road distance using Haversine & Tortuosity Factor
func (c *AmazonLocationClient) CalculateFallbackRoute(pickupLat, pickupLng, dropoffLat, dropoffLng float64) RouteResult {
	straightKm := Haversine(pickupLat, pickupLng, dropoffLat, dropoffLng)
	if straightKm < 0.1 {
		straightKm = 0.5
	}

	roadKm := straightKm * UrbanTortuosityFactor
	durMin := int(math.Ceil((roadKm/DefaultAvgSpeedKmH)*60.0)) + 3 // 3 min pickup buffer
	if durMin < 5 {
		durMin = 5
	}

	return RouteResult{
		DistanceKm:  math.Round(roadKm*100) / 100,
		DurationMin: durMin,
		IsFallback:  true,
		Source:      "haversine_tortuosity_fallback",
	}
}

// Haversine calculates great-circle distance between two GPS coordinates in kilometers
func Haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusKm = 6371.0

	dLat := (lat2 - lat1) * (math.Pi / 180.0)
	dLon := (lon2 - lon1) * (math.Pi / 180.0)

	rLat1 := lat1 * (math.Pi / 180.0)
	rLat2 := lat2 * (math.Pi / 180.0)

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Sin(dLon/2)*math.Sin(dLon/2)*math.Cos(rLat1)*math.Cos(rLat2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadiusKm * c
}

