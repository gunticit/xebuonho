package handler

import (
	"encoding/json"
	"math/rand"
	"net/http"
	"strings"
	"time"

	"github.com/xebuonho/services/api-gateway/internal/event"
	"github.com/xebuonho/services/api-gateway/internal/middleware"
	"github.com/xebuonho/services/api-gateway/internal/orderstate"
	"github.com/xebuonho/services/api-gateway/internal/repository"
)

// DriverHandler serves driver dashboard API (DIP: depends on OrderRepository interface)
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
	repo            repository.OrderRepository
}

type LocationPoint struct {
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	Speed     float64   `json:"speed"`
	Heading   float64   `json:"heading"`
	Timestamp time.Time `json:"timestamp"`
	Battery   int       `json:"battery"`
}

func NewDriverHandler(repo repository.OrderRepository) *DriverHandler {
	return &DriverHandler{
		driverOnline: false, onTrip: false,
		lat: 10.7769, lng: 106.7009,
		repo: repo,
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

	if h.repo != nil {
		pending, err := h.repo.ListPendingRides(r.Context())
		if err == nil {
			writeJSON(w, http.StatusOK, map[string]interface{}{
				"requests": pending,
				"count":    len(pending),
			})
			return
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"requests": []interface{}{},
		"count":    0,
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

	driverID := middleware.GetUserID(r)
	if driverID == "" {
		driverID = "93623b04-ecc7-4654-8846-e05f72ab8069" // default demo driver
	}

	if h.repo != nil && body.RequestID != "" {
		err := h.repo.AcceptRide(r.Context(), body.RequestID, driverID)
		if err != nil {
			writeJSON(w, http.StatusConflict, map[string]interface{}{
				"accepted": false,
				"error":    err.Error(),
				"message":  "Không thể nhận cuốc (cuốc đã có tài xế khác nhận hoặc không được tự nhận cuốc của chính mình).",
			})
			return
		}

		// Observer Pattern: Dispatch EventOrderAccepted
		event.GetDispatcher().Dispatch(r.Context(), event.Event{
			ID:        body.RequestID,
			Type:      event.EventOrderAccepted,
			Payload:   map[string]string{"order_id": body.RequestID, "driver_id": driverID},
			Timestamp: time.Now(),
		})
	}

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
	driverID := middleware.GetUserID(r)
	if driverID == "" {
		driverID = "93623b04-ecc7-4654-8846-e05f72ab8069"
	}

	if h.repo != nil {
		trip, err := h.repo.GetCurrentTrip(r.Context(), driverID)
		if err == nil && trip != nil {
			h.onTrip = true
			writeJSON(w, http.StatusOK, map[string]interface{}{"trip": trip})
			return
		}
	}

	h.onTrip = false
	writeJSON(w, http.StatusOK, map[string]interface{}{"trip": nil})
}

// POST /api/v1/driver/trip/update — Update trip status (advance to next step)
func (h *DriverHandler) UpdateTripStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	var body struct {
		RequestID string `json:"request_id"`
		OrderID   string `json:"order_id"`
		Action    string `json:"action"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	targetID := body.RequestID
	if targetID == "" {
		targetID = body.OrderID
	}

	driverID := middleware.GetUserID(r)
	if driverID == "" {
		driverID = "93623b04-ecc7-4654-8846-e05f72ab8069"
	}

	messages := map[string]string{
		"arrived":   "Đã đến điểm đón. Đang chờ khách...",
		"picked_up": "Đã đón khách. Bắt đầu di chuyển!",
		"completed": "Hoàn thành chuyến! 🎉",
		"cancelled": "Đã hủy chuyến.",
	}

	statusMap := map[string]string{
		"arrived":   "arrived",
		"picked_up": "in_progress",
		"completed": "completed",
		"cancelled": "cancelled",
	}

	if body.Action == "completed" || body.Action == "cancelled" {
		h.onTrip = false
	}

	if h.repo != nil && targetID != "" {
		if mappedStatus, ok := statusMap[body.Action]; ok {
			// State Pattern (FSM): Validate state transition rule
			currentTrip, err := h.repo.GetCurrentTrip(r.Context(), driverID)
			if err == nil && currentTrip != nil {
				if transitionErr := orderstate.ValidateTransition(currentTrip.Status, mappedStatus); transitionErr != nil {
					writeJSON(w, http.StatusBadRequest, map[string]interface{}{
						"error":   transitionErr.Error(),
						"message": "Vi phạm quy trình chuyển đổi trạng thái chuyến đi",
					})
					return
				}
			}

			if err := h.repo.UpdateRideStatus(r.Context(), targetID, driverID, mappedStatus); err != nil {
				writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
				return
			}

			// Observer Pattern: Dispatch EventOrderStatusChanged
			event.GetDispatcher().Dispatch(r.Context(), event.Event{
				ID:   targetID,
				Type: event.EventOrderStatusChanged,
				Payload: map[string]string{
					"order_id":  targetID,
					"driver_id": driverID,
					"status":    mappedStatus,
				},
				Timestamp: time.Now(),
			})
		}
	}

	msg, ok := messages[body.Action]
	if !ok {
		msg = "Đã cập nhật trạng thái."
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"action":    body.Action,
		"message":   msg,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GET /api/v1/driver/earnings — Earnings summary
func (h *DriverHandler) GetEarnings(w http.ResponseWriter, r *http.Request) {
	driverID := middleware.GetUserID(r)
	if driverID == "" {
		driverID = "93623b04-ecc7-4654-8846-e05f72ab8069"
	}

	if h.repo != nil {
		summary, err := h.repo.GetDriverEarnings(r.Context(), driverID)
		if err == nil && summary != nil {
			avgToday := float64(0)
			if summary.TodayTrips > 0 {
				avgToday = summary.TodayEarnings / float64(summary.TodayTrips)
			}
			target := float64(1500000)
			progress := (summary.TodayEarnings / target) * 100
			if progress > 100 {
				progress = 100
			}

			writeJSON(w, http.StatusOK, map[string]interface{}{
				"today": map[string]interface{}{
					"earnings":      summary.TodayEarnings,
					"trips":         summary.TodayTrips,
					"hours_online":  8.0,
					"avg_per_trip":  avgToday,
					"tips":          0,
					"bonus":         0,
					"cancellations": 0,
				},
				"week": map[string]interface{}{
					"earnings": summary.WeekEarnings,
					"trips":    summary.WeekTrips,
					"hours":    40.0,
					"days":     summary.WeekDays,
				},
				"month": map[string]interface{}{
					"earnings": summary.MonthEarnings,
					"trips":    summary.MonthTrips,
					"hours":    160.0,
				},
				"goal": map[string]interface{}{
					"daily_target": target,
					"progress_pct": progress,
				},
			})
			return
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"today": map[string]interface{}{"earnings": 0, "trips": 0},
		"week":  map[string]interface{}{"earnings": 0, "trips": 0, "days": []interface{}{}},
		"month": map[string]interface{}{"earnings": 0, "trips": 0},
		"goal":  map[string]interface{}{"daily_target": 1500000, "progress_pct": 0},
	})
}

// GET /api/v1/driver/history — Trip history
func (h *DriverHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	driverID := middleware.GetUserID(r)
	if driverID == "" {
		driverID = "93623b04-ecc7-4654-8846-e05f72ab8069"
	}

	if h.repo != nil {
		history, err := h.repo.GetDriverHistory(r.Context(), driverID, 30)
		if err == nil {
			var trips []map[string]interface{}
			for _, item := range history {
				trips = append(trips, map[string]interface{}{
					"id":             item.ID,
					"service_type":   item.ServiceType,
					"status":         item.Status,
					"pickup":         item.PickupAddress,
					"dropoff":        item.DropoffAddress,
					"fare":           item.Fare,
					"distance_km":    item.DistanceKm,
					"driver_earning": item.DriverEarning,
					"payment":        item.PaymentMethod,
					"customer_name":  item.CustomerName,
					"time":           item.CreatedAt.Format("15:04"),
					"date":           item.CreatedAt.Format("02/01"),
				})
			}
			writeJSON(w, http.StatusOK, map[string]interface{}{
				"trips": trips,
				"total": len(trips),
			})
			return
		}
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"trips": []interface{}{},
		"total": 0,
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

	// Anti-fraud: Bounds validation
	if body.Lat < -90.0 || body.Lat > 90.0 || body.Lng < -180.0 || body.Lng > 180.0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "coordinates out of valid earth bounds"})
		return
	}

	// Anti-fraud: Speed anomaly check (mock GPS / teleportation filter)
	if body.Speed > 130.0 {
		writeJSON(w, http.StatusUnprocessableEntity, map[string]interface{}{
			"error":    "speed anomaly detected (mock GPS suspected)",
			"received": false,
		})
		return
	}

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
