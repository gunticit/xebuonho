package handler

import (
	"math/rand"
	"net/http"
	"time"
)

// AdminHandler serves admin dashboard and API
type AdminHandler struct{}

func NewAdminHandler() *AdminHandler { return &AdminHandler{} }

// GET /api/v1/admin/stats — Aggregated platform statistics
func (h *AdminHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	now := time.Now()

	stats := map[string]interface{}{
		"timestamp": now.Format(time.RFC3339),
		"overview": map[string]interface{}{
			"total_orders_today":    randomInt(180, 350),
			"total_orders_month":    randomInt(5000, 12000),
			"active_orders":         randomInt(15, 45),
			"total_revenue_today":   randomFloat(25000000, 65000000),
			"total_revenue_month":   randomFloat(800000000, 2000000000),
			"average_order_value":   randomFloat(85000, 165000),
			"total_drivers_online":  randomInt(50, 120),
			"total_drivers_active":  randomInt(30, 80),
			"total_merchants":       randomInt(80, 200),
			"total_customers":       randomInt(2000, 8000),
			"completion_rate":       randomFloat(92.0, 98.5),
			"avg_response_time_sec": randomFloat(12, 45),
		},
		"by_service": map[string]interface{}{
			"ride": map[string]interface{}{
				"orders_today":    randomInt(80, 150),
				"revenue_today":   randomFloat(12000000, 30000000),
				"avg_fare":        randomFloat(55000, 120000),
				"avg_distance_km": randomFloat(4.2, 12.5),
				"cancel_rate":     randomFloat(3.0, 8.0),
			},
			"food_delivery": map[string]interface{}{
				"orders_today":     randomInt(60, 120),
				"revenue_today":    randomFloat(8000000, 20000000),
				"avg_order_value":  randomFloat(95000, 180000),
				"avg_delivery_min": randomFloat(25, 42),
				"cancel_rate":      randomFloat(2.0, 5.0),
			},
			"grocery": map[string]interface{}{
				"orders_today":      randomInt(20, 50),
				"revenue_today":     randomFloat(4000000, 12000000),
				"avg_basket_value":  randomFloat(250000, 500000),
				"substitution_rate": randomFloat(8.0, 18.0),
			},
			"designated_driver": map[string]interface{}{
				"orders_today":  randomInt(5, 20),
				"revenue_today": randomFloat(2000000, 8000000),
				"avg_fare":      randomFloat(200000, 450000),
				"night_pct":     randomFloat(60, 85),
			},
		},
		"peak_hours": []map[string]interface{}{
			{"hour": "07:00-09:00", "orders": randomInt(30, 60), "type": "ride"},
			{"hour": "11:00-13:00", "orders": randomInt(40, 80), "type": "food_delivery"},
			{"hour": "17:00-19:00", "orders": randomInt(50, 90), "type": "ride"},
			{"hour": "19:00-21:00", "orders": randomInt(35, 70), "type": "food_delivery"},
		},
	}

	writeJSON(w, http.StatusOK, stats)
}

// GET /api/v1/admin/orders/recent — Live activity feed
func (h *AdminHandler) GetRecentOrders(w http.ResponseWriter, r *http.Request) {
	serviceTypes := []string{"ride", "food_delivery", "grocery", "designated_driver"}
	statuses := []string{"created", "driver_assigned", "picked_up", "in_progress", "completed", "cancelled_by_customer"}
	names := []string{"Nguyen Van A", "Tran Thi B", "Le Van C", "Pham Thi D", "Hoang Van E", "Vo Thi F", "Dang Van G", "Bui Thi H"}
	pickups := []string{"Landmark 81", "Ben Thanh Market", "Bitexco Tower", "Dam Sen Park", "Nguyen Hue Walking Street", "Phu My Hung"}
	dropoffs := []string{"Tan Son Nhat Airport", "District 7", "Saigon Center", "Thu Duc", "Go Vap", "Binh Tan"}

	var orders []map[string]interface{}
	for i := 0; i < 15; i++ {
		sType := serviceTypes[rand.Intn(len(serviceTypes))]
		orders = append(orders, map[string]interface{}{
			"id":             randomOrderID(),
			"service_type":   sType,
			"customer_name":  names[rand.Intn(len(names))],
			"pickup":         pickups[rand.Intn(len(pickups))],
			"dropoff":        dropoffs[rand.Intn(len(dropoffs))],
			"status":         statuses[rand.Intn(len(statuses))],
			"fare":           randomFloat(35000, 350000),
			"created_at":     time.Now().Add(-time.Duration(rand.Intn(120)) * time.Minute).Format("15:04"),
			"vehicle_type":   vehicleForType(sType),
			"payment_method": []string{"cash", "momo", "zalopay", "vnpay"}[rand.Intn(4)],
		})
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"orders":    orders,
		"total":     len(orders),
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GET /api/v1/admin/revenue — Revenue chart data (7 days)
func (h *AdminHandler) GetRevenueChart(w http.ResponseWriter, r *http.Request) {
	var days []map[string]interface{}
	for i := 6; i >= 0; i-- {
		day := time.Now().AddDate(0, 0, -i)
		days = append(days, map[string]interface{}{
			"date":              day.Format("02/01"),
			"day_name":          dayName(day),
			"ride":              randomFloat(12000000, 35000000),
			"food_delivery":     randomFloat(8000000, 22000000),
			"grocery":           randomFloat(3000000, 10000000),
			"designated_driver": randomFloat(2000000, 8000000),
			"total":             randomFloat(30000000, 70000000),
			"orders":            randomInt(150, 400),
		})
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"chart_data": days,
		"currency":   "VND",
	})
}

// GET /api/v1/admin/drivers — Driver status overview
func (h *AdminHandler) GetDriverStats(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"total_registered": randomInt(200, 500),
		"online":           randomInt(50, 120),
		"on_trip":          randomInt(20, 60),
		"idle":             randomInt(15, 40),
		"offline":          randomInt(100, 300),
		"by_vehicle": map[string]interface{}{
			"bike":    randomInt(80, 200),
			"car":     randomInt(60, 150),
			"premium": randomInt(20, 50),
		},
		"top_drivers": []map[string]interface{}{
			{"name": "Nguyen Van Tai", "trips_today": randomInt(8, 20), "rating": randomFloat(4.7, 5.0), "revenue": randomFloat(800000, 2500000)},
			{"name": "Tran Van Binh", "trips_today": randomInt(6, 15), "rating": randomFloat(4.5, 5.0), "revenue": randomFloat(600000, 2000000)},
			{"name": "Le Minh Duc", "trips_today": randomInt(5, 12), "rating": randomFloat(4.6, 5.0), "revenue": randomFloat(500000, 1800000)},
			{"name": "Pham Thanh Hai", "trips_today": randomInt(4, 10), "rating": randomFloat(4.4, 5.0), "revenue": randomFloat(400000, 1500000)},
			{"name": "Vo Van Hung", "trips_today": randomInt(3, 9), "rating": randomFloat(4.3, 5.0), "revenue": randomFloat(350000, 1200000)},
		},
	})
}

func randomInt(min, max int) int {
	return min + rand.Intn(max-min+1)
}

func randomFloat(min, max float64) float64 {
	return float64(int((min+rand.Float64()*(max-min))*100)) / 100
}

func randomOrderID() string {
	chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	b := make([]byte, 8)
	for i := range b {
		b[i] = chars[rand.Intn(len(chars))]
	}
	return "XBN-" + string(b)
}

func vehicleForType(sType string) string {
	switch sType {
	case "ride":
		return []string{"bike", "car", "premium"}[rand.Intn(3)]
	case "designated_driver":
		return "customer_car"
	default:
		return "bike"
	}
}

func dayName(t time.Time) string {
	names := map[time.Weekday]string{
		time.Monday: "T2", time.Tuesday: "T3", time.Wednesday: "T4",
		time.Thursday: "T5", time.Friday: "T6", time.Saturday: "T7", time.Sunday: "CN",
	}
	return names[t.Weekday()]
}
