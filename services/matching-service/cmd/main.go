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

	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/pkg/kafka"
	"github.com/xebuonho/services/matching-service/internal/config"
	"github.com/xebuonho/services/matching-service/internal/handler"
	"github.com/xebuonho/services/matching-service/internal/repository"
	"github.com/xebuonho/services/matching-service/internal/service"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	"google.golang.org/grpc/health/grpc_health_v1"
)

func main() {
	cfg := config.LoadConfig()
	log.Printf("[%s] Starting on HTTP port %s, gRPC port %s...", cfg.ServiceName, cfg.HTTPPort, cfg.GRPCPort)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// 1. Connect Redis
	redisClient, err := database.ConnectRedis(ctx, cfg.RedisURL)
	if err != nil {
		log.Printf("[%s] Warning: Failed to connect Redis at %s: %v. Running in degraded mode.", cfg.ServiceName, cfg.RedisURL, err)
	} else {
		log.Printf("[%s] Connected to Redis successfully at %s", cfg.ServiceName, cfg.RedisURL)
	}

	// 2. Connect Kafka Producer (optional)
	var kafkaProducer *kafka.Producer
	if cfg.KafkaBrokers != "" {
		kafkaProducer = kafka.NewProducer([]string{cfg.KafkaBrokers}, kafka.TopicOrderEvents, "/services/matching-service")
		defer kafkaProducer.Close()
		log.Printf("[%s] Kafka producer initialized on brokers: %s", cfg.ServiceName, cfg.KafkaBrokers)
	}

	// 3. Initialize Architecture Layers: Repo -> Service -> Handlers
	var geoRepo repository.GeoRepository
	if redisClient != nil {
		geoRepo = repository.NewRedisGeoRepository(redisClient)
	} else {
		// Fallback nil-safe dummy or empty repo
		geoRepo = repository.NewRedisGeoRepository(nil)
	}

	matchingSvc := service.NewMatchingService(geoRepo, kafkaProducer, cfg)
	httpHandler := handler.NewHTTPHandler(matchingSvc)
	grpcHandler := handler.NewMatchingGRPCHandler(matchingSvc)
	// TODO: RegisterMatchingServiceServer(grpcServer, grpcHandler) once proto generated

	// 4. Setup gRPC Server
	grpcServer := grpc.NewServer()
	healthServer := health.NewServer()
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)
	healthServer.SetServingStatus(cfg.ServiceName, grpc_health_v1.HealthCheckResponse_SERVING)

	// 5. Setup HTTP Server
	mux := http.NewServeMux()
	httpHandler.RegisterRoutes(mux)

	httpServer := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
	}

	// 6. Start gRPC listener
	go func() {
		lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
		if err != nil {
			log.Printf("[%s] Failed to listen gRPC: %v", cfg.ServiceName, err)
			return
		}
		log.Printf("[%s] gRPC server listening on :%s", cfg.ServiceName, cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil && err != grpc.ErrServerStopped {
			log.Printf("[%s] gRPC server stopped: %v", cfg.ServiceName, err)
		}
	}()

	// 7. Start HTTP server
	go func() {
		log.Printf("[%s] HTTP server listening on :%s", cfg.ServiceName, cfg.HTTPPort)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[%s] HTTP serve failed: %v", cfg.ServiceName, err)
		}
	}()

	// 8. Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Printf("[%s] Shutting down gracefully...", cfg.ServiceName)
	grpcServer.GracefulStop()

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("[%s] HTTP shutdown error: %v", cfg.ServiceName, err)
	}
	log.Printf("[%s] Service stopped cleanly.", cfg.ServiceName)
}
