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

	// ==========================================
	// Initialize Layers: Repo → Service → Handler
	// ==========================================
	userRepo := repository.NewUserRepository(db)
	authSvc := service.NewAuthService(userRepo, cfg.JWTSecret)
	authHandler := handler.NewAuthHandler(authSvc)

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
	HTTPPort    string
	DatabaseURL string
	JWTSecret   string
}

func loadConfig() Config {
	return Config{
		HTTPPort:    getEnv("HTTP_PORT", "8091"),
		DatabaseURL: getEnv("DATABASE_URL", "postgresql://app:secret@localhost:5432/xebuonho?sslmode=disable"),
		JWTSecret:   getEnv("JWT_SECRET", "dev-secret"),
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
