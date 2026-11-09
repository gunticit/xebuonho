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

type SearchPlaceItem struct {
	Name        string  `json:"name"`
	DisplayName string  `json:"display_name"`
	Lat         float64 `json:"lat"`
	Lng         float64 `json:"lng"`
	Type        string  `json:"type"`
	Emoji       string  `json:"emoji"`
	Keywords    string  `json:"-"`
}

var dakLakPlaces = []SearchPlaceItem{
	{Name: "Pơng Drang", DisplayName: "Thị trấn Pơng Drang, Huyện Krông Búk, Đắk Lắk", Lat: 12.9628, Lng: 108.2465, Type: "town", Emoji: "🏙️", Keywords: "pongdrang pong drang pơngdrang pơng drang krong buk"},
	{Name: "Ngã ba Pơng Drang", DisplayName: "Quốc lộ 14, Thị trấn Pơng Drang, Krông Búk", Lat: 12.9640, Lng: 108.2470, Type: "junction", Emoji: "🚦", Keywords: "nga ba pong drang nga 3 pongdrang ql14 pơngdrang"},
	{Name: "Chợ Pơng Drang", DisplayName: "Chợ Pơng Drang, QL14, Krông Búk, Đắk Lắk", Lat: 12.9615, Lng: 108.2482, Type: "market", Emoji: "🛍️", Keywords: "cho pong drang cho pơngdrang"},
	{Name: "UBND Huyện Krông Búk", DisplayName: "Trung tâm Hành chính Krông Búk, Đắk Lắk", Lat: 12.9700, Lng: 108.2400, Type: "government", Emoji: "🏛️", Keywords: "ubnd krong buk huyen krong buk krongbuk"},
	{Name: "Thị xã Buôn Hồ", DisplayName: "Trung tâm Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9247, Lng: 108.2541, Type: "town", Emoji: "🏙️", Keywords: "buonho buôn hồ tx buon ho thi xa buon ho"},
	{Name: "Chợ Buôn Hồ", DisplayName: "Đường Hùng Vương, Phường An Lạc, Buôn Hồ", Lat: 12.9215, Lng: 108.2520, Type: "market", Emoji: "🛍️", Keywords: "cho buon ho hung vuong an lac"},
	{Name: "Bệnh viện Đa khoa Buôn Hồ", DisplayName: "Trần Hưng Đạo, Phường An Lạc, Buôn Hồ", Lat: 12.9280, Lng: 108.2560, Type: "hospital", Emoji: "🏥", Keywords: "benh vien buon ho bv buon ho tran hung dao"},
	{Name: "Bến xe Buôn Hồ", DisplayName: "Quốc lộ 14, Phường Thiện An, Buôn Hồ", Lat: 12.9180, Lng: 108.2505, Type: "bus_station", Emoji: "🚌", Keywords: "ben xe buon ho bx buon ho ql14"},
	{Name: "Quảng trường Buôn Hồ", DisplayName: "Quảng trường TX. Buôn Hồ, Đắk Lắk", Lat: 12.9230, Lng: 108.2535, Type: "park", Emoji: "🌳", Keywords: "quang truong buon ho"},
	{Name: "Xã Ea Siên", DisplayName: "Xã Ea Siên, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.8500, Lng: 108.3100, Type: "village", Emoji: "🏡", Keywords: "easien ea sien xa ea sien"},
	{Name: "Xã Ea Drông", DisplayName: "Xã Ea Drông, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9800, Lng: 108.3200, Type: "village", Emoji: "🏡", Keywords: "eadrong ea drong xa ea drong"},
	{Name: "Xã Ea Blang", DisplayName: "Xã Ea Blang, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9400, Lng: 108.2800, Type: "village", Emoji: "🏡", Keywords: "eablang ea blang xa ea blang"},
	{Name: "Phường An Lạc", DisplayName: "Phường An Lạc, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9200, Lng: 108.2500, Type: "suburb", Emoji: "🏘️", Keywords: "an lac phuong an lac"},
	{Name: "Phường Thiện An", DisplayName: "Phường Thiện An, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9100, Lng: 108.2650, Type: "suburb", Emoji: "🏘️", Keywords: "thien an phuong thien an"},
	{Name: "Phường Thống Nhất", DisplayName: "Phường Thống Nhất, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9450, Lng: 108.2480, Type: "suburb", Emoji: "🏘️", Keywords: "thong nhat thongnhat"},
	{Name: "Phường Đoàn Kết", DisplayName: "Phường Đoàn Kết, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9350, Lng: 108.2420, Type: "suburb", Emoji: "🏘️", Keywords: "doan ket doanket"},
	{Name: "Phường Bình Tân", DisplayName: "Phường Bình Tân, Thị xã Buôn Hồ, Đắk Lắk", Lat: 12.9150, Lng: 108.2400, Type: "suburb", Emoji: "🏘️", Keywords: "binh tan binhtan"},
	{Name: "Xã Chư Kabô", DisplayName: "Xã Chư Kabô, Huyện Krông Búk, Đắk Lắk", Lat: 12.9850, Lng: 108.2300, Type: "village", Emoji: "🏡", Keywords: "chukabo chu kabo krong buk"},
	{Name: "Xã Cư Pơng", DisplayName: "Xã Cư Pơng, Huyện Krông Búk, Đắk Lắk", Lat: 13.0200, Lng: 108.2100, Type: "village", Emoji: "🏡", Keywords: "cupong cu pong cu poeng"},
	{Name: "Xã Cư Né", DisplayName: "Xã Cư Né, Huyện Krông Búk, Đắk Lắk", Lat: 13.0100, Lng: 108.2600, Type: "village", Emoji: "🏡", Keywords: "cune cu ne krong buk"},
	{Name: "Thị trấn Ea Drăng", DisplayName: "Thị trấn Ea Drăng, Huyện Ea H'leo, Đắk Lắk", Lat: 13.2100, Lng: 108.1900, Type: "town", Emoji: "🏙️", Keywords: "eadrang eahleo ea hleo ea drang"},
	{Name: "Thị trấn Quảng Phú", DisplayName: "Thị trấn Quảng Phú, Huyện Cư M'gar, Đắk Lắk", Lat: 12.8100, Lng: 108.1100, Type: "town", Emoji: "🏙️", Keywords: "quang phu quangphu cumgar cu mgar"},
	{Name: "Thị trấn Krông Năng", DisplayName: "Thị trấn Krông Năng, Huyện Krông Năng, Đắk Lắk", Lat: 12.9500, Lng: 108.4300, Type: "town", Emoji: "🏙️", Keywords: "krong nang krongnang"},
	{Name: "Thị trấn Phước An", DisplayName: "Thị trấn Phước An, Huyện Krông Pắc, Đắk Lắk", Lat: 12.7200, Lng: 108.3100, Type: "town", Emoji: "🏙️", Keywords: "phuoc an phuocan krong pac"},
	{Name: "Ngã 6 Buôn Ma Thuột", DisplayName: "Tượng đài Chiến thắng, TP. Buôn Ma Thuột", Lat: 12.6840, Lng: 108.0475, Type: "landmark", Emoji: "⭐", Keywords: "nga 6 bmt nga sau bmt buon ma thuot bmt"},
	{Name: "Sân bay Buôn Ma Thuột (BMV)", DisplayName: "Cảng hàng không Buôn Ma Thuột, Hòa Thắng, BMT", Lat: 12.6680, Lng: 108.1200, Type: "aeroway", Emoji: "✈️", Keywords: "san bay bmt san bay buon ma thuot bmv"},
	{Name: "Bến xe Liên tỉnh Đắk Lắk", DisplayName: "Km4 Nguyễn Tất Thành, TP. Buôn Ma Thuột", Lat: 12.7050, Lng: 108.0700, Type: "bus_station", Emoji: "🚌", Keywords: "ben xe phia bac bmt ben xe lien tinh dak lak"},
}

func stripVietnamese(s string) string {
	s = strings.ToLower(s)
	replacer := strings.NewReplacer(
		"à", "a", "á", "a", "ả", "a", "ã", "a", "ạ", "a",
		"ă", "a", "ằ", "a", "ắ", "a", "ẳ", "a", "ẵ", "a", "ặ", "a",
		"â", "a", "ầ", "a", "ấ", "a", "ẩ", "a", "ẫ", "a", "ậ", "a",
		"è", "e", "é", "e", "ẻ", "e", "ẽ", "e", "ẹ", "e",
		"ê", "e", "ề", "e", "ế", "e", "ể", "e", "ễ", "e", "ệ", "e",
		"ì", "i", "í", "i", "ỉ", "i", "ĩ", "i", "ị", "i",
		"ò", "o", "ó", "o", "ỏ", "o", "õ", "o", "ọ", "o",
		"ô", "o", "ồ", "o", "ố", "o", "ổ", "o", "ỗ", "o", "ộ", "o",
		"ơ", "o", "ờ", "o", "ớ", "o", "ở", "o", "ỡ", "o", "ợ", "o",
		"ù", "u", "ú", "u", "ủ", "u", "ũ", "u", "ụ", "u",
		"ư", "u", "ừ", "u", "ứ", "u", "ử", "u", "ữ", "u", "ự", "u",
		"ỳ", "y", "ý", "y", "ỷ", "y", "ỹ", "y", "ỵ", "y",
		"đ", "d", "'", "", " ", "", "-", "", "_", "",
	)
	return replacer.Replace(s)
}

// SearchPlaces handles GET /api/v1/maps/search?q=...&lat=...&lng=...
func (h *MapsHandler) SearchPlaces(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if len(q) < 2 {
		writeJSON(w, http.StatusOK, []SearchPlaceItem{})
		return
	}

	normQ := stripVietnamese(q)
	var matched []SearchPlaceItem

	// 1. Match local high-accuracy Dak Lak & Buon Ho places
	for _, p := range dakLakPlaces {
		normName := stripVietnamese(p.Name)
		normDisplay := stripVietnamese(p.DisplayName)
		normKey := stripVietnamese(p.Keywords)

		if strings.Contains(normName, normQ) || strings.Contains(normDisplay, normQ) || strings.Contains(normKey, normQ) {
			matched = append(matched, p)
		}
	}

	// 2. Query expansion for Nominatim (e.g. "pơngdrang" -> "Pơng Drang")
	queryVariants := []string{q}
	if normQ == "pongdrang" {
		queryVariants = append(queryVariants, "Pơng Drang")
	} else if normQ == "eahleo" {
		queryVariants = append(queryVariants, "Ea H'leo")
	} else if normQ == "krongbuk" {
		queryVariants = append(queryVariants, "Krông Búk")
	} else if normQ == "buonho" {
		queryVariants = append(queryVariants, "Buôn Hồ")
	} else if normQ == "bmt" {
		queryVariants = append(queryVariants, "Buôn Ma Thuột")
	}

	// 3. Fallback to Nominatim if local matches < 4
	if len(matched) < 4 {
		for _, variant := range queryVariants {
			osmResults := h.searchNominatim(variant)
			for _, item := range osmResults {
				// Deduplicate by proximity (< 200m)
				isDup := false
				for _, m := range matched {
					if math.Abs(m.Lat-item.Lat) < 0.002 && math.Abs(m.Lng-item.Lng) < 0.002 {
						isDup = true
						break
					}
				}
				if !isDup {
					matched = append(matched, item)
				}
			}
			if len(matched) >= 6 {
				break
			}
		}
	}

	writeJSON(w, http.StatusOK, matched)
}

func (h *MapsHandler) searchNominatim(q string) []SearchPlaceItem {
	url := fmt.Sprintf("https://nominatim.openstreetmap.org/search?q=%s&format=json&countrycodes=vn&limit=6", urlQueryEscape(q))
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", "XeBuonHo-Router/1.0 (contact@xebuonho.vn)")
	req.Header.Set("Accept-Language", "vi")

	resp, err := h.httpClient.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil
	}

	var data []struct {
		Name        string `json:"name"`
		DisplayName string `json:"display_name"`
		Lat         string `json:"lat"`
		Lon         string `json:"lon"`
		Type        string `json:"type"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil
	}

	var items []SearchPlaceItem
	for _, d := range data {
		lat, _ := strconv.ParseFloat(d.Lat, 64)
		lng, _ := strconv.ParseFloat(d.Lon, 64)
		name := d.Name
		if name == "" {
			parts := strings.Split(d.DisplayName, ",")
			if len(parts) > 0 {
				name = strings.TrimSpace(parts[0])
			}
		}
		items = append(items, SearchPlaceItem{
			Name:        name,
			DisplayName: d.DisplayName,
			Lat:         lat,
			Lng:         lng,
			Type:        d.Type,
			Emoji:       "📍",
		})
	}
	return items
}

func urlQueryEscape(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(s, " ", "+"), "'", "%27")
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
