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
)

func main() {
	cfg := loadConfig()
	logger := setupLogger(cfg.LogLevel)

	// ==========================================
	// Initialize Dependencies
	// ==========================================
	// db := connectPostgres(cfg.DatabaseURL)
	// redisClient := connectRedis(cfg.RedisURL)
	// kafkaProducer := connectKafka(cfg.KafkaBrokers, "ride.events")

	// ==========================================
	// Initialize Services
	// ==========================================
	// rideRepo := repository.NewRideRepository(db)
	// rideService := service.NewRideService(rideRepo, redisClient, kafkaProducer)
	// rideHandler := handler.NewRideHandler(rideService)

	// ==========================================
	// gRPC Server
	// ==========================================
	grpcServer := grpc.NewServer(
	// grpc.UnaryInterceptor(middleware.ChainUnary(
	//     middleware.LoggingInterceptor(logger),
	//     middleware.RecoveryInterceptor(),
	//     middleware.AuthInterceptor(cfg.JWTSecret),
	// )),
	)

	// Register gRPC services
	// pb.RegisterRideServiceServer(grpcServer, rideHandler)
	healthServer := health.NewServer()
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	// ==========================================
	// HTTP Server (REST + Health check)
	// ==========================================
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok","service":"ride-service"}`))
	})

	httpServer := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// ==========================================
	// Start Servers
	// ==========================================
	go func() {
		lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
		if err != nil {
			log.Fatalf("Failed to listen gRPC: %v", err)
		}
		logger.Printf("gRPC server listening on :%s", cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("Failed to serve gRPC: %v", err)
		}
	}()

	go func() {
		logger.Printf("HTTP server listening on :%s", cfg.HTTPPort)
		if err := httpServer.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("Failed to serve HTTP: %v", err)
		}
	}()

	// ==========================================
	// Graceful Shutdown
	// ==========================================
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Println("Shutting down servers...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	grpcServer.GracefulStop()
	httpServer.Shutdown(ctx)
	logger.Println("Servers stopped gracefully")
}

// Config holds service configuration
type Config struct {
	HTTPPort     string
	GRPCPort     string
	DatabaseURL  string
	RedisURL     string
	KafkaBrokers string
	JWTSecret    string
	LogLevel     string
}

func loadConfig() Config {
	return Config{
		HTTPPort:     getEnv("HTTP_PORT", "8080"),
		GRPCPort:     getEnv("GRPC_PORT", "50051"),
		DatabaseURL:  getEnv("DATABASE_URL", "postgresql://app:secret@localhost:5432/xebuonho?sslmode=disable"),
		RedisURL:     getEnv("REDIS_URL", "localhost:6379"),
		KafkaBrokers: getEnv("KAFKA_BROKERS", "localhost:9092"),
		JWTSecret:    getEnv("JWT_SECRET", "dev-secret-change-me"),
		LogLevel:     getEnv("LOG_LEVEL", "info"),
	}
}

func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}

func setupLogger(level string) *log.Logger {
	return log.New(os.Stdout, "[ride-service] ", log.LstdFlags|log.Lshortfile)
}
