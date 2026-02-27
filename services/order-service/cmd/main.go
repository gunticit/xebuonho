package main

import (
	"context"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"

	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/services/order-service/internal/handler"
	"github.com/xebuonho/services/order-service/internal/repository"
	"github.com/xebuonho/services/order-service/internal/service"
)

func main() {
	cfg := loadConfig()
	logger := setupLogger()
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
	orderRepo := repository.NewOrderRepository(db)
	itemRepo := repository.NewOrderItemRepository(db)
	orderSvc := service.NewOrderService(orderRepo, itemRepo)
	orderHandler := handler.NewOrderGRPCHandler(orderSvc)

	_ = orderHandler // Will be registered when proto-gen is ready

	// ==========================================
	// gRPC Server
	// ==========================================
	grpcServer := grpc.NewServer()
	// pb.RegisterOrderServiceServer(grpcServer, orderHandler)
	healthServer := health.NewServer()
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	// ==========================================
	// HTTP Server
	// ==========================================
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok","service":"order-service"}`))
	})

	httpServer := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
	}

	// Start servers
	go func() {
		lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
		if err != nil {
			log.Fatalf("Failed to listen gRPC: %v", err)
		}
		logger.Printf("gRPC server listening on :%s", cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("gRPC serve failed: %v", err)
		}
	}()

	go func() {
		logger.Printf("HTTP server listening on :%s", cfg.HTTPPort)
		if err := httpServer.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("HTTP serve failed: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Println("Shutting down...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	grpcServer.GracefulStop()
	httpServer.Shutdown(shutdownCtx)
	logger.Println("Stopped")
}

type Config struct {
	HTTPPort            string
	GRPCPort            string
	DatabaseURL         string
	RedisURL            string
	KafkaBrokers        string
	MerchantServiceAddr string
	JWTSecret           string
}

func loadConfig() Config {
	return Config{
		HTTPPort:            getEnv("HTTP_PORT", "8088"),
		GRPCPort:            getEnv("GRPC_PORT", "50058"),
		DatabaseURL:         getEnv("DATABASE_URL", "postgresql://app:secret@localhost:5432/xebuonho?sslmode=disable"),
		RedisURL:            getEnv("REDIS_URL", "localhost:6379"),
		KafkaBrokers:        getEnv("KAFKA_BROKERS", "localhost:9092"),
		MerchantServiceAddr: getEnv("MERCHANT_SERVICE", "localhost:50059"),
		JWTSecret:           getEnv("JWT_SECRET", "dev-secret"),
	}
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func setupLogger() *log.Logger {
	return log.New(os.Stdout, "[order-service] ", log.LstdFlags|log.Lshortfile)
}
