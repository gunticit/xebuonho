package router

import (
	"embed"
	"encoding/json"
	"io"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/xebuonho/services/api-gateway/internal/grpcclient"
	"github.com/xebuonho/services/api-gateway/internal/handler"
	"github.com/xebuonho/services/api-gateway/internal/middleware"
	"github.com/xebuonho/services/api-gateway/internal/ws"
)

//go:embed static
var staticFiles embed.FS

// NewRouter creates the main API router with all routes
func NewRouter(jwtSecret string, rideClient *grpcclient.RideClient, orderClient *grpcclient.OrderClient, merchantClient *grpcclient.MerchantClient) http.Handler {
	mux := http.NewServeMux()

	rideH := handler.NewRideHandler(rideClient)
	orderH := handler.NewOrderHandler(orderClient)
	merchantH := handler.NewMerchantHandler(merchantClient)
	adminH := handler.NewAdminHandler()
	driverH := handler.NewDriverHandler()

	// ==========================================
	// Dashboard (root URL)
	// ==========================================
	staticFS, _ := fs.Sub(staticFiles, "static")
	mux.Handle("/", http.FileServer(http.FS(staticFS)))

	// ==========================================
	// Admin API (no auth for dashboard access)
	// ==========================================
	mux.HandleFunc("/api/v1/admin/stats", adminH.GetStats)
	mux.HandleFunc("/api/v1/admin/orders/recent", adminH.GetRecentOrders)
	mux.HandleFunc("/api/v1/admin/revenue", adminH.GetRevenueChart)
	mux.HandleFunc("/api/v1/admin/drivers", adminH.GetDriverStats)

	// ==========================================
	// Auth API (proxy to user-service, no JWT required)
	// ==========================================
	userServiceURL := getEnvDefault("USER_SERVICE_URL", "http://localhost:8091")
	mux.HandleFunc("/api/v1/auth/", func(w http.ResponseWriter, r *http.Request) {
		proxyToService(w, r, userServiceURL)
	})

	// ==========================================
	// Driver API
	// ==========================================
	mux.Handle("/api/v1/driver/", driverH)

	// ==========================================
	// Public endpoints (no auth)
	// ==========================================
	mux.HandleFunc("/health", healthCheck)
	mux.HandleFunc("/api/v1/merchants/nearby", merchantH.ListNearbyMerchants)
	mux.HandleFunc("/api/v1/merchants/search", merchantH.SearchMerchants)

	// ==========================================
	// WebSocket Realtime Notifications
	// ==========================================
	notifHub := ws.NewHub()
	go notifHub.Run()

	mux.HandleFunc("/ws", notifHub.HandleWebSocket)

	// Notification API
	mux.HandleFunc("/api/v1/notifications", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "GET":
			userID := r.URL.Query().Get("user_id")
			notifs := notifHub.GetNotifications(userID)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]interface{}{
				"notifications": notifs,
				"online":        notifHub.GetOnlineCount(),
			})
		case "POST":
			var body struct {
				UserID  string `json:"user_id"`
				Role    string `json:"role"`
				Type    string `json:"type"`
				Title   string `json:"title"`
				Message string `json:"message"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				http.Error(w, `{"error":"invalid body"}`, 400)
				return
			}
			notif := ws.Notification{
				Type:    body.Type,
				Title:   body.Title,
				Message: body.Message,
			}
			if body.UserID != "" {
				notifHub.SendToUser(body.UserID, notif)
			} else if body.Role != "" {
				notifHub.SendToRole(body.Role, notif)
			} else {
				notifHub.Broadcast(notif)
			}
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(201)
			json.NewEncoder(w).Encode(map[string]string{"status": "sent"})
		default:
			http.Error(w, `{"error":"method not allowed"}`, 405)
		}
	})

	// Demo notifications (remove in production)
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		messages := []string{
			"🚗 Có tài xế mới online gần bạn",
			"🎉 Khuyến mãi 20%% cho chuyến tiếp theo",
			"📦 Đơn hàng GrabFood đang được chuẩn bị",
			"⭐ Bạn nhận được đánh giá 5 sao!",
			"🔔 Cập nhật hệ thống: thêm tính năng mới",
		}
		i := 0
		for range ticker.C {
			notifHub.Broadcast(ws.Notification{
				Type:    "system",
				Title:   "Thông báo",
				Message: messages[i%len(messages)],
			})
			i++
		}
	}()

	// ==========================================
	// Protected endpoints (require auth)
	// ==========================================
	auth := middleware.AuthMiddleware(jwtSecret)

	// Rides
	mux.Handle("/api/v1/rides/estimate", auth(http.HandlerFunc(rideH.EstimateFare)))
	mux.Handle("/api/v1/rides", auth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "POST":
			rideH.CreateRide(w, r)
		case "GET":
			rideH.ListRides(w, r)
		default:
			http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})))

	// Orders
	mux.Handle("/api/v1/orders/estimate", auth(http.HandlerFunc(orderH.EstimatePrice)))
	mux.Handle("/api/v1/orders", auth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "POST":
			orderH.CreateOrder(w, r)
		case "GET":
			orderH.ListOrders(w, r)
		default:
			http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})))

	// Merchants (protected creation)
	mux.Handle("/api/v1/merchants", auth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			merchantH.CreateMerchant(w, r)
		} else {
			http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		}
	})))

	// Dynamic path routing
	mux.Handle("/api/v1/", auth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		switch {
		case strings.HasPrefix(path, "/api/v1/rides/"):
			if strings.HasSuffix(path, "/cancel") && r.Method == "PATCH" {
				rideH.CancelRide(w, r)
			} else if r.Method == "GET" {
				rideH.GetRide(w, r)
			} else {
				http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
			}

		case strings.HasPrefix(path, "/api/v1/orders/"):
			if strings.HasSuffix(path, "/status") && r.Method == "PATCH" {
				orderH.UpdateOrderStatus(w, r)
			} else if strings.HasSuffix(path, "/cancel") && r.Method == "PATCH" {
				orderH.CancelOrder(w, r)
			} else if r.Method == "GET" {
				orderH.GetOrder(w, r)
			} else {
				http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
			}

		case strings.HasPrefix(path, "/api/v1/merchants/"):
			if strings.HasSuffix(path, "/menu") {
				if r.Method == "GET" {
					merchantH.GetMenu(w, r)
				} else if r.Method == "POST" {
					merchantH.CreateMenuItem(w, r)
				} else {
					http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
				}
			} else if r.Method == "GET" {
				merchantH.GetMerchant(w, r)
			} else {
				http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
			}

		default:
			http.NotFound(w, r)
		}
	})))

	// Middleware chain: CORS → Logging → Rate Limit → Router
	rateLimiter := middleware.NewRateLimiter(100)
	var h http.Handler = mux
	h = rateLimiter.RateLimitMiddleware(h)
	h = middleware.LoggingMiddleware(h)
	h = middleware.CORSMiddleware(h)

	return h
}

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok","service":"api-gateway","version":"1.0.0"}`))
}

// proxyToService forwards the request to an internal service
func proxyToService(w http.ResponseWriter, r *http.Request, serviceURL string) {
	target, err := url.Parse(serviceURL)
	if err != nil {
		http.Error(w, `{"error":"service unavailable"}`, http.StatusBadGateway)
		return
	}

	// Build proxy request
	proxyURL := target.ResolveReference(r.URL)
	proxyReq, err := http.NewRequestWithContext(r.Context(), r.Method, proxyURL.String(), r.Body)
	if err != nil {
		http.Error(w, `{"error":"proxy error"}`, http.StatusBadGateway)
		return
	}

	// Copy headers
	for key, values := range r.Header {
		for _, v := range values {
			proxyReq.Header.Add(key, v)
		}
	}

	resp, err := http.DefaultClient.Do(proxyReq)
	if err != nil {
		http.Error(w, `{"error":"service unavailable"}`, http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	// Copy response headers
	for key, values := range resp.Header {
		for _, v := range values {
			w.Header().Add(key, v)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func getEnvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
