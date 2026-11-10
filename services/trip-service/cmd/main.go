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
	"github.com/xebuonho/services/trip-service/internal/config"
	"github.com/xebuonho/services/trip-service/internal/handler"
	"github.com/xebuonho/services/trip-service/internal/repository"
	"github.com/xebuonho/services/trip-service/internal/service"
)

func main() {
	cfg := config.LoadConfig()
	log.Printf("[%s] Starting Trip Service...", cfg.ServiceName)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Database Connection
	db, err := database.ConnectPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect PostgreSQL: %v", err)
	}
	defer db.Close()
	log.Println("Connected to PostgreSQL")

	// 2. Initialize Layers: Repo → Service → Handler
	tripRepo := repository.NewTripRepository(db)
	tripSvc := service.NewTripService(tripRepo)
	tripHandler := handler.NewTripHandler(tripSvc, cfg.JWTSecret)

	// 3. gRPC Server (health only; TripService pb registration pending proto-gen)
	grpcServer := grpc.NewServer()
	healthServer := health.NewServer()
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	go func() {
		lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
		if err != nil {
			log.Fatalf("Failed to listen gRPC: %v", err)
		}
		log.Printf("gRPC server listening on :%s", cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("gRPC serve failed: %v", err)
		}
	}()

	// 4. HTTP Server
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok","service":"trip-service"}`))
	})
	tripHandler.Register(mux)

	httpServer := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
	}

	go func() {
		log.Printf("HTTP server listening on :%s", cfg.HTTPPort)
		if err := httpServer.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("HTTP serve failed: %v", err)
		}
	}()

	// 5. Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down Trip Service...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	grpcServer.GracefulStop()
	httpServer.Shutdown(shutdownCtx)
	log.Println("Stopped")
}
