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
	"github.com/xebuonho/services/payment-service/internal/config"
	"github.com/xebuonho/services/payment-service/internal/repository"
	"github.com/xebuonho/services/payment-service/internal/service"
	"google.golang.org/grpc"
)

func main() {
	cfg := config.LoadConfig()
	log.Printf("[%s] Starting Payment Service...", cfg.ServiceName)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 1. Database Connection
	db, err := database.ConnectPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect DB: %v", err)
	}

	// 2. Initialize Layers
	repo := repository.NewPaymentRepository(db)
	paymentSvc := service.NewPaymentService(repo)

	// 3. gRPC Server
	grpcServer := grpc.NewServer()
	// Register handlers here

	go func() {
		lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
		if err != nil {
			log.Fatalf("Failed to listen gRPC: %v", err)
		}
		log.Printf("gRPC server listening on :%s", cfg.GRPCPort)
		if err := grpcServer.Serve(lis); err != nil {
			log.Fatalf("gRPC server failed: %v", err)
		}
	}()

	// 4. HTTP Health Check
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	go func() {
		log.Printf("HTTP health check listening on :%s", cfg.HTTPPort)
		if err := http.ListenAndServe(":"+cfg.HTTPPort, nil); err != nil {
			log.Printf("HTTP server error: %v", err)
		}
	}()

	// Graceful Shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down Payment Service...")
	grpcServer.GracefulStop()
}
