package handler

import (
	"encoding/json"
	"fmt"
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

type MapsHandler struct {
	httpClient *http.Client
}

func NewMapsHandler() *MapsHandler {
	return &MapsHandler{
		httpClient: &http.Client{
			Timeout: 3 * time.Second,
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

	// Build clean short address
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

	// Krông Búk / Buôn Hồ region (XeBuonHo core area)
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

