package router

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"net/url"
	"os"
	"runtime"
	"strings"
	"time"

	"github.com/xebuonho/services/api-gateway/internal/event"
	"github.com/xebuonho/services/api-gateway/internal/grpcclient"
	"github.com/xebuonho/services/api-gateway/internal/handler"
	"github.com/xebuonho/services/api-gateway/internal/middleware"
	"github.com/xebuonho/services/api-gateway/internal/repository"
	"github.com/xebuonho/services/api-gateway/internal/ws"
)

//go:embed static
var staticFiles embed.FS

// NewRouter creates the main API router with all routes
func NewRouter(jwtSecret string, rideClient *grpcclient.RideClient, orderClient *grpcclient.OrderClient, merchantClient *grpcclient.MerchantClient, repo *repository.PostgresRepo) http.Handler {
	mux := http.NewServeMux()

	rideH := handler.NewRideHandler(rideClient, repo)
	orderH := handler.NewOrderHandler(orderClient)
	merchantH := handler.NewMerchantHandler(merchantClient, repo)
	adminH := handler.NewAdminHandler()
	driverH := handler.NewDriverHandler(repo)
	mapsH := handler.NewMapsHandler()

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
	// Payment, Wallet & Invoices API (proxy to payment-service)
	// ==========================================
	paymentServiceURL := getEnvDefault("PAYMENT_SERVICE_URL", "http://localhost:8087")
	mux.HandleFunc("/api/v1/payments/", func(w http.ResponseWriter, r *http.Request) {
		proxyToService(w, r, paymentServiceURL)
	})
	mux.HandleFunc("/api/v1/wallets/", func(w http.ResponseWriter, r *http.Request) {
		proxyToService(w, r, paymentServiceURL)
	})
	mux.HandleFunc("/api/v1/invoices/", func(w http.ResponseWriter, r *http.Request) {
		proxyToService(w, r, paymentServiceURL)
	})

	// ==========================================
	// Trips API — history & ratings (proxy to trip-service, JWT required)
	// ==========================================
	tripServiceURL := getEnvDefault("TRIP_SERVICE_URL", "http://localhost:8086")
	tripAuth := middleware.AuthMiddleware(jwtSecret)
	mux.Handle("/api/v1/trips", tripAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		proxyToService(w, r, tripServiceURL)
	})))
	mux.Handle("/api/v1/trips/", tripAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		proxyToService(w, r, tripServiceURL)
	})))
	mux.HandleFunc("/api/v1/drivers/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/rating-summary") {
			proxyToService(w, r, tripServiceURL)
			return
		}
		http.NotFound(w, r)
	})

	// ==========================================
	// Legal & Compliance APIs (NĐ 13/2023 PDPD & NĐ 10/2020 Transport)
	// ==========================================
	mux.HandleFunc("/api/v1/compliance/privacy-policy", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"version": "2026.1",
			"effective_date": "2026-07-01",
			"controller": "XeBuonHo Platform Co., Ltd",
			"nd13_compliant": true,
			"data_retention_days": 180,
			"user_rights": ["access", "export", "delete", "withdraw_consent"],
			"contact_dpo": "dpo@xebuonho.vn"
		}`))
	})
	mux.HandleFunc("/api/v1/compliance/nd10-telemetry", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"standard": "ND10/2020/ND-CP",
			"agency": "Cuc Duong Bo Viet Nam",
			"status": "connected",
			"telemetry_interval_sec": 30
		}`))
	})

	// ==========================================
	// Driver API (JWT required — verified identity for KYC gates)
	// ==========================================
	driverAuth := middleware.AuthMiddleware(jwtSecret)
	mux.Handle("/api/v1/driver/", driverAuth(driverH))

	// ==========================================
	// Public endpoints (no auth)
	// ==========================================
	mux.HandleFunc("/health", healthCheck)
	mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		var mem runtime.MemStats
		runtime.ReadMemStats(&mem)
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		fmt.Fprintf(w, "# HELP xebuonho_goroutines Number of running goroutines\n")
		fmt.Fprintf(w, "# TYPE xebuonho_goroutines gauge\n")
		fmt.Fprintf(w, "xebuonho_goroutines %d\n", runtime.NumGoroutine())
		fmt.Fprintf(w, "# HELP xebuonho_mem_alloc_bytes Bytes of allocated memory\n")
		fmt.Fprintf(w, "# TYPE xebuonho_mem_alloc_bytes gauge\n")
		fmt.Fprintf(w, "xebuonho_mem_alloc_bytes %d\n", mem.Alloc)
	})
	mux.HandleFunc("/api/v1/merchants/nearby", merchantH.ListNearbyMerchants)
	mux.HandleFunc("/api/v1/merchants/search", merchantH.SearchMerchants)
	mux.HandleFunc("/api/v1/maps/reverse-geocode", mapsH.ReverseGeocode)
	mux.HandleFunc("/api/v1/maps/route", mapsH.GetRoute)
	mux.HandleFunc("/api/v1/maps/search", mapsH.SearchPlaces)
	mux.HandleFunc("/api/v1/merchants/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "/menu") {
			merchantH.GetMenu(w, r)
			return
		}
		merchantH.GetMerchant(w, r)
	})

	// ==========================================
	// WebSocket Realtime Notifications
	// ==========================================
	notifHub := ws.NewHub()
	// WS handshake identity must come from a signed JWT (query token)
	notifHub.TokenAuthenticator = func(token string) (string, string, error) {
		claims, err := middleware.ParseToken(token, jwtSecret)
		if err != nil || claims == nil {
			return "", "", fmt.Errorf("invalid token")
		}
		return claims.UserID, claims.Role, nil
	}
	go notifHub.Run()

	// Scheduled rides worker: flip 'scheduled' → 'created' when due so the
	// booking appears in the driver pending list at the booked time.
	if repo != nil {
		go func() {
			ticker := time.NewTicker(30 * time.Second)
			defer ticker.Stop()
			for range ticker.C {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				n, err := repo.ActivateDueScheduledRides(ctx)
				cancel()
				if err != nil {
					log.Printf("[scheduled-worker] error: %v", err)
				} else if n > 0 {
					log.Printf("[scheduled-worker] activated %d scheduled ride(s)", n)
				}
			}
		}()
	}

	// Observer Pattern: wire Event Dispatcher to WebSocket NotifHub.
	// Rider-targeted events use SendToUser(customer_id) — no more global broadcast.
	event.GetDispatcher().Subscribe(event.EventOrderCreated, func(ctx context.Context, e event.Event) error {
		notifHub.SendToRole("driver", ws.Notification{
			Type:    "new_ride_request",
			Title:   "Có cuốc xe mới!",
			Message: "Khách hàng vừa đặt chuyến gần bạn. Nhấn để nhận cuốc.",
		})
		return nil
	})
	event.GetDispatcher().Subscribe(event.EventOrderAccepted, func(ctx context.Context, e event.Event) error {
		m, _ := e.Payload.(map[string]interface{})
		customerID, _ := m["customer_id"].(string)
		if customerID == "" {
			return nil
		}
		driverName, _ := m["driver_name"].(string)
		plate, _ := m["license_plate"].(string)
		notifHub.SendToUser(customerID, ws.Notification{
			Type:    "ride_accepted",
			Title:   "Tài xế đã nhận cuốc",
			Message: fmt.Sprintf("%s (%s) đang trên đường đến điểm đón bạn.", driverName, plate),
			Data:    m,
		})
		return nil
	})
	event.GetDispatcher().Subscribe(event.EventOrderStatusChanged, func(ctx context.Context, e event.Event) error {
		m, _ := e.Payload.(map[string]interface{})
		customerID, _ := m["customer_id"].(string)
		if customerID == "" {
			return nil
		}
		status, _ := m["status"].(string)
		messages := map[string]string{
			"accepted":    "Tài xế đang trên đường đến điểm đón.",
			"arrived":     "Tài xế đã đến điểm đón. Vui lòng ra xe!",
			"in_progress": "Đang di chuyển đến điểm đến.",
			"completed":   "Chuyến đi hoàn tất. Cảm ơn bạn đã sử dụng XeBuonHo!",
			"cancelled":   "Chuyến đi đã bị hủy.",
		}
		notifHub.SendToUser(customerID, ws.Notification{
			Type:    "ride_status_updated",
			Title:   "Cập nhật hành trình",
			Message: messages[status],
			Data:    m,
		})
		return nil
	})

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
			if strings.HasSuffix(path, "/messages") {
				rideH.RideMessages(w, r)
			} else if strings.HasSuffix(path, "/cancel") && r.Method == "PATCH" {
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
