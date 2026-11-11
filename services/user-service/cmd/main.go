package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/services/user-service/internal/handler"
	"github.com/xebuonho/services/user-service/internal/repository"
	"github.com/xebuonho/services/user-service/internal/service"
	"github.com/xebuonho/services/user-service/internal/storage"
)

func main() {
	cfg := loadConfig()
	logger := log.New(os.Stdout, "[user-service] ", log.LstdFlags|log.Lshortfile)
	ctx := context.Background()

	// ==========================================
	// Initialize Dependencies
	// ==========================================
	db, err := database.ConnectPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect PostgreSQL: %v", err)
	}
	defer db.Close()
	logger.Println("Connected to PostgreSQL")

	redisClient, rErr := database.ConnectRedis(ctx, cfg.RedisURL)
	if rErr != nil {
		logger.Printf("⚠️ Redis connection warning: %v (running with in-memory fallback)", rErr)
	} else {
		logger.Println("Connected to Redis for OTP & Session")
	}

	// ==========================================
	// Initialize Layers: Repo → Service → Handler
	// ==========================================
	minioStore := storage.NewMinIOStore(
		cfg.MinIOEndpoint, cfg.MinIOAccessKey, cfg.MinIOSecretKey, cfg.MinIOBucket, cfg.MinIOSecure,
	)
	userRepo := repository.NewUserRepository(db)
	authSvc := service.NewAuthService(userRepo, cfg.JWTSecret, redisClient, minioStore)
	authHandler := handler.NewAuthHandler(authSvc, redisClient)

	// ==========================================
	// HTTP Server
	// ==========================================
	mux := http.NewServeMux()

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok","service":"user-service"}`))
	})

	// Auth routes
	mux.Handle("/api/v1/auth/", authHandler)

	// CORS middleware
	corsHandler := corsMiddleware(mux)

	httpServer := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      corsHandler,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
	}

	go func() {
		logger.Printf("🌐 HTTP server listening on :%s", cfg.HTTPPort)
		if err := httpServer.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("HTTP serve failed: %v", err)
		}
	}()

	logger.Println("✅ User service started")

	// ==========================================
	// Graceful Shutdown
	// ==========================================
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Println("Shutting down...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	httpServer.Shutdown(shutdownCtx)
	logger.Println("Stopped ✅")
}

type Config struct {
	HTTPPort      string
	DatabaseURL   string
	RedisURL      string
	JWTSecret     string
	MinIOEndpoint string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOBucket   string
	MinIOSecure   bool
}

func loadConfig() Config {
	return Config{
		HTTPPort:       getEnv("HTTP_PORT", "8091"),
		DatabaseURL:    getEnv("DATABASE_URL", "postgresql://app:secret@localhost:5432/xebuonho?sslmode=disable"),
		RedisURL:       getEnv("REDIS_URL", "localhost:6379"),
		JWTSecret:      getEnv("JWT_SECRET", "dev-secret"),
		MinIOEndpoint:  getEnv("MINIO_ENDPOINT", "localhost:9000"),
		MinIOAccessKey: getEnv("MINIO_ACCESS_KEY", "minioadmin"),
		MinIOSecretKey: getEnv("MINIO_SECRET_KEY", "minioadmin123"),
		MinIOBucket:    getEnv("MINIO_BUCKET", "xebuonho-kyc"),
		MinIOSecure:    getEnv("MINIO_SECURE", "false") == "true",
	}
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}
