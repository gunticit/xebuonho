package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/xebuonho/services/api-gateway/internal/router"
)

func main() {
	cfg := loadConfig()
	logger := setupLogger()

	// ==========================================
	// Build Router with all routes & middleware
	// ==========================================
	handler := router.NewRouter(cfg.JWTSecret)

	// ==========================================
	// HTTP Server
	// ==========================================
	server := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Printf("🚀 API Gateway listening on http://localhost:%s", cfg.HTTPPort)
		logger.Println("📍 Health: GET /health")
		logger.Println("📍 Rides:  POST/GET /api/v1/rides")
		logger.Println("📍 Orders: POST/GET /api/v1/orders")
		logger.Println("📍 Merchants: GET /api/v1/merchants/nearby")
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// ==========================================
	// Graceful Shutdown
	// ==========================================
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Println("Shutting down API Gateway...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	server.Shutdown(ctx)
	logger.Println("API Gateway stopped")
}

type Config struct {
	HTTPPort            string
	JWTSecret           string
	RideServiceAddr     string
	OrderServiceAddr    string
	MerchantServiceAddr string
}

func loadConfig() Config {
	return Config{
		HTTPPort:            getEnv("HTTP_PORT", "8000"),
		JWTSecret:           getEnv("JWT_SECRET", "dev-secret"),
		RideServiceAddr:     getEnv("RIDE_SERVICE", "localhost:50051"),
		OrderServiceAddr:    getEnv("ORDER_SERVICE", "localhost:50058"),
		MerchantServiceAddr: getEnv("MERCHANT_SERVICE", "localhost:50059"),
	}
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func setupLogger() *log.Logger {
	return log.New(os.Stdout, "[api-gateway] ", log.LstdFlags|log.Lshortfile)
}
