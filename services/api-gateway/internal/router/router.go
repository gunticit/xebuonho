package router

import (
	"net/http"
	"strings"

	"github.com/xebuonho/services/api-gateway/internal/handler"
	"github.com/xebuonho/services/api-gateway/internal/middleware"
)

// NewRouter creates the main API router with all routes
func NewRouter(jwtSecret string) http.Handler {
	mux := http.NewServeMux()

	rideH := handler.NewRideHandler()
	orderH := handler.NewOrderHandler()
	merchantH := handler.NewMerchantHandler()

	// ==========================================
	// Public endpoints (no auth)
	// ==========================================
	mux.HandleFunc("/health", healthCheck)
	mux.HandleFunc("/api/v1/merchants/nearby", merchantH.ListNearbyMerchants)
	mux.HandleFunc("/api/v1/merchants/search", merchantH.SearchMerchants)

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
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
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
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})))

	// Merchants (protected)
	mux.Handle("/api/v1/merchants", auth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			merchantH.CreateMerchant(w, r)
		} else {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})))

	// Dynamic path routing for resources with IDs
	mux.Handle("/api/v1/", auth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path

		switch {
		// Rides: /api/v1/rides/{id} or /api/v1/rides/{id}/cancel
		case strings.HasPrefix(path, "/api/v1/rides/"):
			if strings.HasSuffix(path, "/cancel") && r.Method == "PATCH" {
				rideH.CancelRide(w, r)
			} else if r.Method == "GET" {
				rideH.GetRide(w, r)
			} else {
				http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			}

		// Orders: /api/v1/orders/{id}, /api/v1/orders/{id}/status, /api/v1/orders/{id}/cancel
		case strings.HasPrefix(path, "/api/v1/orders/"):
			if strings.HasSuffix(path, "/status") && r.Method == "PATCH" {
				orderH.UpdateOrderStatus(w, r)
			} else if strings.HasSuffix(path, "/cancel") && r.Method == "PATCH" {
				orderH.CancelOrder(w, r)
			} else if r.Method == "GET" {
				orderH.GetOrder(w, r)
			} else {
				http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			}

		// Merchants: /api/v1/merchants/{id}, /api/v1/merchants/{id}/menu
		case strings.HasPrefix(path, "/api/v1/merchants/"):
			if strings.HasSuffix(path, "/menu") {
				if r.Method == "GET" {
					merchantH.GetMenu(w, r)
				} else if r.Method == "POST" {
					merchantH.CreateMenuItem(w, r)
				} else {
					http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
				}
			} else if r.Method == "GET" {
				merchantH.GetMerchant(w, r)
			} else {
				http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			}

		default:
			http.NotFound(w, r)
		}
	})))

	// Apply global middleware: CORS → Logging → Rate Limit → Router
	rateLimiter := middleware.NewRateLimiter(100) // 100 req/s per IP
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
