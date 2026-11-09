package handler

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type ReverseGeocodeResponse struct {
	Address      string  `json:"address"`
	ShortAddress string  `json:"short_address"`
	DisplayName  string  `json:"display_name"`
	Lat          float64 `json:"lat"`
	Lng          float64 `json:"lng"`
	Source       string  `json:"source"`
}

type RoutePoint struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

type RouteResponse struct {
	DistanceKm  float64      `json:"distance_km"`
	DurationMin int          `json:"duration_min"`
	Points      []RoutePoint `json:"points"`
	Source      string       `json:"source"`
}

type MapsHandler struct {
	httpClient *http.Client
}

func NewMapsHandler() *MapsHandler {
	return &MapsHandler{
		httpClient: &http.Client{
			Timeout: 4 * time.Second,
		},
	}
}

// ReverseGeocode handles GET /api/v1/maps/reverse-geocode?lat=...&lng=...
func (h *MapsHandler) ReverseGeocode(w http.ResponseWriter, r *http.Request) {
	latStr := r.URL.Query().Get("lat")
	lngStr := r.URL.Query().Get("lng")

	lat, err1 := strconv.ParseFloat(latStr, 64)
	lng, err2 := strconv.ParseFloat(lngStr, 64)

	if err1 != nil || err2 != nil {
		writeError(w, http.StatusBadRequest, "invalid lat or lng parameter")
		return
	}

	// 1. Try OpenStreetMap Nominatim with VN language & custom User-Agent
	res, err := h.fetchNominatim(lat, lng)
	if err == nil && res.Address != "" {
		writeJSON(w, http.StatusOK, res)
		return
	}

	// 2. Fallback to regional bounding box detection
	fallback := h.fallbackRegion(lat, lng)
	writeJSON(w, http.StatusOK, fallback)
}

// GetRoute handles GET /api/v1/maps/route?pickup_lat=...&pickup_lng=...&dropoff_lat=...&dropoff_lng=...
func (h *MapsHandler) GetRoute(w http.ResponseWriter, r *http.Request) {
	pLatStr := r.URL.Query().Get("pickup_lat")
	pLngStr := r.URL.Query().Get("pickup_lng")
	dLatStr := r.URL.Query().Get("dropoff_lat")
	dLngStr := r.URL.Query().Get("dropoff_lng")

	pLat, e1 := strconv.ParseFloat(pLatStr, 64)
	pLng, e2 := strconv.ParseFloat(pLngStr, 64)
	dLat, e3 := strconv.ParseFloat(dLatStr, 64)
	dLng, e4 := strconv.ParseFloat(dLngStr, 64)

	if e1 != nil || e2 != nil || e3 != nil || e4 != nil {
		writeError(w, http.StatusBadRequest, "invalid pickup or dropoff coordinates")
		return
	}

	// 1. Try OSRM Real Road Network
	route, err := h.fetchOSRMRoute(pLat, pLng, dLat, dLng)
	if err == nil && len(route.Points) > 0 {
		writeJSON(w, http.StatusOK, route)
		return
	}

	// 2. Fallback Curved Route Generator
	fallback := h.fallbackCurvedRoute(pLat, pLng, dLat, dLng)
	writeJSON(w, http.StatusOK, fallback)
}

func (h *MapsHandler) fetchOSRMRoute(pLat, pLng, dLat, dLng float64) (RouteResponse, error) {
	url := fmt.Sprintf("https://router.project-osrm.org/route/v1/driving/%.6f,%.6f;%.6f,%.6f?overview=full&geometries=geojson",
		pLng, pLat, dLng, dLat)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return RouteResponse{}, err
	}
	req.Header.Set("User-Agent", "XeBuonHo-Router/1.0 (contact@xebuonho.vn)")

	resp, err := h.httpClient.Do(req)
	if err != nil {
		return RouteResponse{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return RouteResponse{}, fmt.Errorf("osrm returned status %d", resp.StatusCode)
	}

	var osrmResp struct {
		Code   string `json:"code"`
		Routes []struct {
			Distance float64 `json:"distance"` // meters
			Duration float64 `json:"duration"` // seconds
			Geometry struct {
				Coordinates [][]float64 `json:"coordinates"` // [lng, lat]
			} `json:"geometry"`
		} `json:"routes"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&osrmResp); err != nil {
		return RouteResponse{}, err
	}

	if osrmResp.Code != "Ok" || len(osrmResp.Routes) == 0 {
		return RouteResponse{}, fmt.Errorf("no osrm route found")
	}

	r0 := osrmResp.Routes[0]
	var points []RoutePoint
	for _, c := range r0.Geometry.Coordinates {
		if len(c) >= 2 {
			points = append(points, RoutePoint{
				Lat: c[1],
				Lng: c[0],
			})
		}
	}

	distKm := math.Round((r0.Distance/1000.0)*100) / 100
	durMin := int(math.Ceil(r0.Duration / 60.0))
	if durMin < 3 {
		durMin = 3
	}

	return RouteResponse{
		DistanceKm:  distKm,
		DurationMin: durMin,
		Points:      points,
		Source:      "osrm_road_network",
	}, nil
}

func (h *MapsHandler) fallbackCurvedRoute(pLat, pLng, dLat, dLng float64) RouteResponse {
	// Haversine base distance
	const earthR = 6371.0
	dLatRad := (dLat - pLat) * math.Pi / 180.0
	dLngRad := (dLng - pLng) * math.Pi / 180.0
	rLat1 := pLat * math.Pi / 180.0
	rLat2 := dLat * math.Pi / 180.0

	a := math.Sin(dLatRad/2)*math.Sin(dLatRad/2) +
		math.Sin(dLngRad/2)*math.Sin(dLngRad/2)*math.Cos(rLat1)*math.Cos(rLat2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	straightKm := earthR * c
	if straightKm < 0.1 {
		straightKm = 0.5
	}

	// Road tortuosity factor = 1.35
	roadKm := math.Round(straightKm*1.35*100) / 100
	durMin := int(math.Ceil((roadKm/28.0)*60.0)) + 3

	// Generate 25 smooth sinusoidal road waypoints simulating turns
	steps := 25
	points := make([]RoutePoint, steps+1)
	for i := 0; i <= steps; i++ {
		t := float64(i) / float64(steps)
		// Lateral curve offset
		curveOffset := math.Sin(t*math.Pi*2) * 0.002
		lat := pLat + (dLat-pLat)*t + curveOffset
		lng := pLng + (dLng-pLng)*t - curveOffset
		points[i] = RoutePoint{
			Lat: math.Round(lat*1000000) / 1000000,
			Lng: math.Round(lng*1000000) / 1000000,
		}
	}

	return RouteResponse{
		DistanceKm:  roadKm,
		DurationMin: durMin,
		Points:      points,
		Source:      "tortuosity_interpolated",
	}
}

func (h *MapsHandler) fetchNominatim(lat, lng float64) (ReverseGeocodeResponse, error) {
	url := fmt.Sprintf("https://nominatim.openstreetmap.org/reverse?format=json&lat=%.6f&lon=%.6f&zoom=18&addressdetails=1", lat, lng)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return ReverseGeocodeResponse{}, err
	}
	req.Header.Set("User-Agent", "XeBuonHo-Delivery-App/1.0 (contact@xebuonho.vn)")
	req.Header.Set("Accept-Language", "vi")

	resp, err := h.httpClient.Do(req)
	if err != nil {
		return ReverseGeocodeResponse{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return ReverseGeocodeResponse{}, fmt.Errorf("nominatim returned status %d", resp.StatusCode)
	}

	var data struct {
		DisplayName string `json:"display_name"`
		Address     struct {
			Road        string `json:"road"`
			Suburb      string `json:"suburb"`
			Neighbour   string `json:"neighbourhood"`
			Quarter     string `json:"quarter"`
			Town        string `json:"town"`
			City        string `json:"city"`
			County      string `json:"county"`
			State       string `json:"state"`
			Country     string `json:"country"`
		} `json:"address"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return ReverseGeocodeResponse{}, err
	}

	var parts []string
	if data.Address.Road != "" {
		parts = append(parts, data.Address.Road)
	}
	if data.Address.Suburb != "" {
		parts = append(parts, data.Address.Suburb)
	} else if data.Address.Neighbour != "" {
		parts = append(parts, data.Address.Neighbour)
	} else if data.Address.Quarter != "" {
		parts = append(parts, data.Address.Quarter)
	}

	district := data.Address.Town
	if district == "" {
		district = data.Address.City
	}
	if district == "" {
		district = data.Address.County
	}
	if district != "" {
		parts = append(parts, district)
	}

	state := data.Address.State
	if state != "" {
		state = strings.TrimPrefix(state, "Tỉnh ")
		state = strings.TrimPrefix(state, "Thành phố ")
		parts = append(parts, state)
	}

	fullAddress := strings.Join(parts, ", ")
	if fullAddress == "" {
		fullAddress = data.DisplayName
	}

	short := district
	if short == "" && len(parts) > 0 {
		short = parts[len(parts)-1]
	}

	return ReverseGeocodeResponse{
		Address:      fullAddress,
		ShortAddress: short,
		DisplayName:  data.DisplayName,
		Lat:          lat,
		Lng:          lng,
		Source:       "nominatim",
	}, nil
}

func (h *MapsHandler) fallbackRegion(lat, lng float64) ReverseGeocodeResponse {
	var addr, short string

	if lat >= 12.80 && lat <= 13.15 && lng >= 108.10 && lng <= 108.45 {
		if lat > 12.95 {
			addr = "Huyện Krông Búk, Đắk Lắk"
			short = "Krông Búk"
		} else {
			addr = "Thị xã Buôn Hồ, Đắk Lắk"
			short = "TX. Buôn Hồ"
		}
	} else if lat >= 12.50 && lat <= 12.80 && lng >= 107.90 && lng <= 108.20 {
		addr = "TP. Buôn Ma Thuột, Đắk Lắk"
		short = "Buôn Ma Thuột"
	} else if lat >= 10.60 && lat <= 10.95 && lng >= 106.50 && lng <= 106.90 {
		addr = "TP. Hồ Chí Minh"
		short = "TP.HCM"
	} else if lat >= 20.90 && lat <= 21.20 && lng >= 105.65 && lng <= 106.00 {
		addr = "TP. Hà Nội"
		short = "Hà Nội"
	} else if lat >= 15.95 && lat <= 16.20 && lng >= 108.10 && lng <= 108.35 {
		addr = "TP. Đà Nẵng"
		short = "Đà Nẵng"
	} else {
		addr = fmt.Sprintf("Vị trí (%.4f, %.4f)", lat, lng)
		short = fmt.Sprintf("%.4f, %.4f", lat, lng)
	}

	return ReverseGeocodeResponse{
		Address:      addr,
		ShortAddress: short,
		DisplayName:  addr,
		Lat:          lat,
		Lng:          lng,
		Source:       "regional_heuristic",
	}
}
