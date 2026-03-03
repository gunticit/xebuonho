package handler

import (
	"encoding/json"
	"math/rand"
	"net/http"
	"strings"
	"time"
)

// DriverHandler serves driver dashboard API
type DriverHandler struct {
	driverOnline    bool
	onTrip          bool
	lat             float64
	lng             float64
	speed           float64
	heading         float64
	locationHistory []LocationPoint
	sosActive       bool
	sosTimestamp    time.Time
}

type LocationPoint struct {
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	Speed     float64   `json:"speed"`
	Heading   float64   `json:"heading"`
	Timestamp time.Time `json:"timestamp"`
	Battery   int       `json:"battery"`
}

func NewDriverHandler() *DriverHandler {
	return &DriverHandler{
		driverOnline: false, onTrip: false,
		lat: 10.7769, lng: 106.7009,
	}
}

// POST /api/v1/driver/toggle — Toggle online/offline
func (h *DriverHandler) ToggleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	h.driverOnline = !h.driverOnline
	if !h.driverOnline {
		h.onTrip = false
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"online":    h.driverOnline,
		"on_trip":   h.onTrip,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GET /api/v1/driver/status — Current driver state
func (h *DriverHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	state := "offline"
	if h.driverOnline && h.onTrip {
		state = "on_trip"
	} else if h.driverOnline {
		state = "online"
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"state":             state,
		"online":            h.driverOnline,
		"on_trip":           h.onTrip,
		"online_duration":   randomInt(0, 480),
		"trips_completed":   randomInt(3, 18),
		"acceptance_rate":   randomFloat(85.0, 99.0),
		"rating":            randomFloat(4.6, 5.0),
		"today_earnings":    randomFloat(350000, 1800000),
		"vehicle_type":      "car",
		"license_plate":     "51F-123.45",
		"name":              "Nguyen Van Tai",
		"avatar_url":        "",
		"last_location_lat": 10.7769,
		"last_location_lng": 106.7009,
		"battery_level":     randomInt(20, 95),
		"network_quality":   []string{"good", "fair", "excellent"}[rand.Intn(3)],
	})
}

// GET /api/v1/driver/requests — Pending ride requests
func (h *DriverHandler) GetRequests(w http.ResponseWriter, r *http.Request) {
	if !h.driverOnline || h.onTrip {
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"requests": []interface{}{},
			"count":    0,
		})
		return
	}

	serviceTypes := []string{"ride", "food_delivery", "grocery", "designated_driver"}
	pickups := []string{"Landmark 81, Bình Thạnh", "Bến Thành Market, Q.1", "Bitexco Tower, Q.1", "Phú Mỹ Hưng, Q.7", "Nguyễn Huệ Walking Street"}
	dropoffs := []string{"Sân bay Tân Sơn Nhất", "Quận 7, PMHK", "Saigon Center, Q.1", "Thủ Đức City", "Gò Vấp", "Bình Tân"}
	customerNames := []string{"Trần Thị Bích", "Lê Văn Cường", "Phạm Thanh Hà", "Hoàng Minh Đức", "Võ Thị Mai"}

	sType := serviceTypes[rand.Intn(len(serviceTypes))]
	req := map[string]interface{}{
		"id":              randomOrderID(),
		"service_type":    sType,
		"customer_name":   customerNames[rand.Intn(len(customerNames))],
		"customer_rating": randomFloat(4.2, 5.0),
		"pickup_address":  pickups[rand.Intn(len(pickups))],
		"pickup_lat":      10.7769 + (rand.Float64()-0.5)*0.05,
		"pickup_lng":      106.7009 + (rand.Float64()-0.5)*0.05,
		"dropoff_address": dropoffs[rand.Intn(len(dropoffs))],
		"dropoff_lat":     10.8231 + (rand.Float64()-0.5)*0.05,
		"dropoff_lng":     106.6297 + (rand.Float64()-0.5)*0.05,
		"distance_km":     randomFloat(2.0, 18.0),
		"fare_estimate":   randomFloat(25000, 350000),
		"payment_method":  []string{"cash", "momo", "zalopay", "vnpay"}[rand.Intn(4)],
		"vehicle_type":    vehicleForType(sType),
		"expires_in":      randomInt(15, 30),
		"created_at":      time.Now().Format("15:04"),
		"notes":           randomNote(sType),
	}

	// For food/grocery, add items
	if sType == "food_delivery" {
		req["merchant_name"] = []string{"Phở 2000", "Bún Chả Hà Nội", "Cơm Tấm Sài Gòn", "Bánh Mì Huỳnh Hoa"}[rand.Intn(4)]
		req["items_count"] = randomInt(1, 5)
	} else if sType == "grocery" {
		req["merchant_name"] = []string{"Co.opmart Q1", "Vinmart Landmark", "Bach Hoa Xanh", "Lotte Mart"}[rand.Intn(4)]
		req["items_count"] = randomInt(3, 15)
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"requests": []interface{}{req},
		"count":    1,
	})
}

// POST /api/v1/driver/accept — Accept a request
func (h *DriverHandler) AcceptRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var body struct {
		RequestID string `json:"request_id"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	h.onTrip = true
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"accepted":   true,
		"request_id": body.RequestID,
		"message":    "Đã nhận chuyến! Hãy đến điểm đón khách.",
	})
}

// POST /api/v1/driver/decline — Decline a request
func (h *DriverHandler) DeclineRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"declined": true,
		"message":  "Đã từ chối. Chờ chuyến tiếp theo...",
	})
}

// GET /api/v1/driver/trip/current — Current active trip
func (h *DriverHandler) GetCurrentTrip(w http.ResponseWriter, r *http.Request) {
	if !h.onTrip {
		writeJSON(w, http.StatusOK, map[string]interface{}{"trip": nil})
		return
	}

	sType := []string{"ride", "food_delivery", "grocery", "designated_driver"}[rand.Intn(4)]
	statuses := []string{"driver_assigned", "arriving", "arrived", "picked_up", "in_progress"}
	status := statuses[rand.Intn(len(statuses))]

	trip := map[string]interface{}{
		"id":              randomOrderID(),
		"service_type":    sType,
		"status":          status,
		"customer_name":   "Phạm Thanh Hà",
		"customer_phone":  "0901-xxx-xxx",
		"customer_rating": 4.8,
		"pickup_address":  "Landmark 81, Bình Thạnh",
		"pickup_lat":      10.7942,
		"pickup_lng":      106.7217,
		"dropoff_address": "Sân bay Tân Sơn Nhất",
		"dropoff_lat":     10.8231,
		"dropoff_lng":     106.6580,
		"distance_km":     randomFloat(4.0, 15.0),
		"duration_min":    randomInt(12, 45),
		"fare_estimate":   randomFloat(55000, 280000),
		"payment_method":  "cash",
		"vehicle_type":    vehicleForType(sType),
		"notes":           randomNote(sType),
		"started_at":      time.Now().Add(-time.Duration(randomInt(5, 30)) * time.Minute).Format("15:04"),
	}

	if sType == "food_delivery" || sType == "grocery" {
		trip["merchant_name"] = "Phở 2000 Bến Thành"
		trip["items_count"] = randomInt(2, 6)
	}

	// Status progression hints
	nextActions := map[string]string{
		"driver_assigned": "Đang đến điểm đón",
		"arriving":        "Sắp đến nơi đón",
		"arrived":         "Đã đến, chờ khách",
		"picked_up":       "Đã đón khách, bắt đầu di chuyển",
		"in_progress":     "Đang trên đường đến đích",
	}
	trip["next_action"] = nextActions[status]

	writeJSON(w, http.StatusOK, map[string]interface{}{"trip": trip})
}

// POST /api/v1/driver/trip/update — Update trip status (advance to next step)
func (h *DriverHandler) UpdateTripStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var body struct {
		Action string `json:"action"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	messages := map[string]string{
		"arrived":   "Đã đến điểm đón. Đang chờ khách...",
		"picked_up": "Đã đón khách. Bắt đầu di chuyển!",
		"completed": "Hoàn thành chuyến! 🎉",
		"cancelled": "Đã hủy chuyến.",
	}

	if body.Action == "completed" || body.Action == "cancelled" {
		h.onTrip = false
	}

	msg, ok := messages[body.Action]
	if !ok {
		msg = "Đã cập nhật trạng thái."
	}

	fare := float64(0)
	if body.Action == "completed" {
		fare = randomFloat(55000, 280000)
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"action":     body.Action,
		"message":    msg,
		"fare_final": fare,
		"timestamp":  time.Now().Format(time.RFC3339),
	})
}

// GET /api/v1/driver/earnings — Earnings summary
func (h *DriverHandler) GetEarnings(w http.ResponseWriter, r *http.Request) {
	todayEarnings := randomFloat(400000, 1800000)
	todayTrips := randomInt(5, 20)

	// Weekly breakdown
	var weekDays []map[string]interface{}
	for i := 6; i >= 0; i-- {
		day := time.Now().AddDate(0, 0, -i)
		weekDays = append(weekDays, map[string]interface{}{
			"date":     day.Format("02/01"),
			"day_name": dayName(day),
			"earnings": randomFloat(300000, 2000000),
			"trips":    randomInt(4, 22),
			"hours":    randomFloat(4, 12),
		})
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"today": map[string]interface{}{
			"earnings":      todayEarnings,
			"trips":         todayTrips,
			"hours_online":  randomFloat(2, 10),
			"avg_per_trip":  todayEarnings / float64(todayTrips),
			"tips":          randomFloat(0, 80000),
			"bonus":         randomFloat(0, 50000),
			"cancellations": randomInt(0, 2),
		},
		"week": map[string]interface{}{
			"earnings": randomFloat(3000000, 10000000),
			"trips":    randomInt(40, 120),
			"hours":    randomFloat(35, 70),
			"days":     weekDays,
		},
		"month": map[string]interface{}{
			"earnings": randomFloat(12000000, 35000000),
			"trips":    randomInt(150, 500),
			"hours":    randomFloat(150, 300),
		},
		"goal": map[string]interface{}{
			"daily_target": 1500000,
			"progress_pct": (todayEarnings / 1500000) * 100,
		},
	})
}

// GET /api/v1/driver/history — Trip history
func (h *DriverHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	serviceTypes := []string{"ride", "food_delivery", "grocery", "designated_driver"}
	pickups := []string{"Landmark 81", "Bến Thành", "Bitexco", "Phú Mỹ Hưng", "Nguyễn Huệ", "Thảo Điền"}
	dropoffs := []string{"TSN Airport", "Q.7", "Saigon Center", "Thủ Đức", "Gò Vấp", "Bình Tân", "Q.2"}

	var trips []map[string]interface{}
	for i := 0; i < 15; i++ {
		sType := serviceTypes[rand.Intn(len(serviceTypes))]
		status := "completed"
		if rand.Float64() < 0.1 {
			status = "cancelled"
		}
		trips = append(trips, map[string]interface{}{
			"id":           randomOrderID(),
			"service_type": sType,
			"status":       status,
			"pickup":       pickups[rand.Intn(len(pickups))],
			"dropoff":      dropoffs[rand.Intn(len(dropoffs))],
			"fare":         randomFloat(25000, 350000),
			"distance_km":  randomFloat(1.5, 20.0),
			"duration_min": randomInt(8, 55),
			"payment":      []string{"cash", "momo", "zalopay", "vnpay"}[rand.Intn(4)],
			"rating":       randomFloat(4.0, 5.0),
			"time":         time.Now().Add(-time.Duration(randomInt(30, 720)) * time.Minute).Format("15:04"),
			"date":         time.Now().Add(-time.Duration(randomInt(0, 3)) * 24 * time.Hour).Format("02/01"),
		})
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"trips": trips,
		"total": len(trips),
	})
}

// POST /api/v1/driver/location/update — Update driver location (called from browser GPS)
func (h *DriverHandler) UpdateLocation(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var body struct {
		Lat     float64 `json:"lat"`
		Lng     float64 `json:"lng"`
		Speed   float64 `json:"speed"`
		Heading float64 `json:"heading"`
		Battery int     `json:"battery"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	h.lat = body.Lat
	h.lng = body.Lng
	h.speed = body.Speed
	h.heading = body.Heading

	point := LocationPoint{
		Lat:       body.Lat,
		Lng:       body.Lng,
		Speed:     body.Speed,
		Heading:   body.Heading,
		Timestamp: time.Now(),
		Battery:   body.Battery,
	}
	h.locationHistory = append(h.locationHistory, point)

	// Keep last 500 points (about 8 min at 1/s)
	if len(h.locationHistory) > 500 {
		h.locationHistory = h.locationHistory[len(h.locationHistory)-500:]
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"received":   true,
		"points":     len(h.locationHistory),
		"sos_active": h.sosActive,
	})
}

// GET /api/v1/driver/location/history — Get tracked location history
func (h *DriverHandler) GetLocationHistory(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"driver_name":   "Nguyen Van Tai",
		"license_plate": "51F-123.45",
		"vehicle":       "car",
		"current_lat":   h.lat,
		"current_lng":   h.lng,
		"speed_kmh":     h.speed,
		"heading":       h.heading,
		"online":        h.driverOnline,
		"on_trip":       h.onTrip,
		"sos_active":    h.sosActive,
		"sos_timestamp": h.sosTimestamp.Format(time.RFC3339),
		"total_points":  len(h.locationHistory),
		"history":       h.locationHistory,
	})
}

// POST /api/v1/driver/sos — Trigger emergency SOS
func (h *DriverHandler) TriggerSOS(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	var body struct {
		Action string `json:"action"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	if body.Action == "cancel" {
		h.sosActive = false
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"sos_active": false,
			"message":    "🟢 SOS đã được tắt.",
		})
		return
	}

	h.sosActive = true
	h.sosTimestamp = time.Now()
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"sos_active": true,
		"message":    "🚨 SOS đã kích hoạt! Vị trí đang được chia sẻ với tổng đài và người thân.",
		"emergency_contacts": []map[string]string{
			{"name": "Tổng đài 112", "phone": "112"},
			{"name": "Hotline Xebuonho", "phone": "1900-6868"},
			{"name": "Người thân", "phone": "0901-xxx-xxx"},
		},
		"location": map[string]float64{
			"lat": h.lat,
			"lng": h.lng,
		},
		"timestamp": h.sosTimestamp.Format(time.RFC3339),
	})
}

// GET /api/v1/driver/location/nearby — Get nearby drivers (for admin tracking map)
func (h *DriverHandler) GetNearbyDrivers(w http.ResponseWriter, r *http.Request) {
	baseLat := 10.7769
	baseLng := 106.7009
	if h.lat != 0 {
		baseLat = h.lat
		baseLng = h.lng
	}

	names := []string{"Nguyen Van Tai", "Tran Van Binh", "Le Minh Duc", "Pham Thanh Hai", "Vo Van Hung",
		"Dang Thi Lan", "Bui Van Nam", "Hoang Van Duc", "Nguyen Thi Mai", "Le Van Phong"}
	statuses := []string{"online", "on_trip", "online", "on_trip", "online",
		"online", "on_trip", "online", "online", "on_trip"}
	vehicles := []string{"car", "bike", "car", "bike", "car", "bike", "car", "premium", "bike", "car"}
	plates := []string{"51F-123.45", "51B-987.65", "51D-456.78", "51E-321.09", "51A-654.32",
		"51C-111.22", "51F-333.44", "51D-555.66", "51B-777.88", "51A-999.00"}

	var drivers []map[string]interface{}
	for i := 0; i < 10; i++ {
		dlat := baseLat + (rand.Float64()-0.5)*0.03
		dlng := baseLng + (rand.Float64()-0.5)*0.03
		drivers = append(drivers, map[string]interface{}{
			"id":            i + 1,
			"name":          names[i],
			"status":        statuses[i],
			"vehicle":       vehicles[i],
			"license_plate": plates[i],
			"lat":           dlat,
			"lng":           dlng,
			"speed":         randomFloat(0, 60),
			"heading":       randomFloat(0, 360),
			"rating":        randomFloat(4.3, 5.0),
			"trips_today":   randomInt(2, 15),
			"battery":       randomInt(15, 95),
		})
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"drivers":    drivers,
		"total":      len(drivers),
		"center_lat": baseLat,
		"center_lng": baseLng,
	})
}

func randomNote(sType string) string {
	switch sType {
	case "food_delivery":
		notes := []string{"Gọi trước khi đến", "Để cửa bảo vệ", "Ít hành, thêm tương ớt", ""}
		return notes[rand.Intn(len(notes))]
	case "grocery":
		notes := []string{"Mua thêm túi đựng", "Gọi nếu hết hàng", "Cần hóa đơn", ""}
		return notes[rand.Intn(len(notes))]
	case "designated_driver":
		notes := []string{"Xe số tự động", "Có camera hành trình", "Xe gửi hầm B2", ""}
		return notes[rand.Intn(len(notes))]
	default:
		return ""
	}
}

// Route handler for /api/v1/driver/ paths
func (h *DriverHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/driver")

	switch {
	case path == "/status" && r.Method == "GET":
		h.GetStatus(w, r)
	case path == "/toggle" && r.Method == "POST":
		h.ToggleStatus(w, r)
	case path == "/requests" && r.Method == "GET":
		h.GetRequests(w, r)
	case path == "/accept" && r.Method == "POST":
		h.AcceptRequest(w, r)
	case path == "/decline" && r.Method == "POST":
		h.DeclineRequest(w, r)
	case path == "/trip/current" && r.Method == "GET":
		h.GetCurrentTrip(w, r)
	case path == "/trip/update" && r.Method == "POST":
		h.UpdateTripStatus(w, r)
	case path == "/earnings" && r.Method == "GET":
		h.GetEarnings(w, r)
	case path == "/history" && r.Method == "GET":
		h.GetHistory(w, r)
	case path == "/location/update" && r.Method == "POST":
		h.UpdateLocation(w, r)
	case path == "/location/history" && r.Method == "GET":
		h.GetLocationHistory(w, r)
	case path == "/location/nearby" && r.Method == "GET":
		h.GetNearbyDrivers(w, r)
	case path == "/sos" && r.Method == "POST":
		h.TriggerSOS(w, r)
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
	}
}
