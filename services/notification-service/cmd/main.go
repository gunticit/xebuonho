package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/xebuonho/pkg/kafka"
	"github.com/xebuonho/services/notification-service/internal/eventhandlers"
)

func main() {
	cfg := loadConfig()
	logger := log.New(os.Stdout, "[notification-service] ", log.LstdFlags|log.Lshortfile)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// ==========================================
	// Kafka Consumers
	// ==========================================
	brokers := strings.Split(cfg.KafkaBrokers, ",")

	// Consumer for order events
	orderConsumer := kafka.NewConsumer(brokers, kafka.TopicOrderEvents, "notification-service")
	eventhandlers.RegisterNotificationHandlers(orderConsumer)
	logger.Printf("📦 Order event consumer registered (topic: %s)", kafka.TopicOrderEvents)

	// Consumer for ride events
	rideConsumer := kafka.NewConsumer(brokers, kafka.TopicRideEvents, "notification-service")
	eventhandlers.RegisterRideHandlers(rideConsumer)
	logger.Printf("🚗 Ride event consumer registered (topic: %s)", kafka.TopicRideEvents)

	// Consumer for driver events
	driverConsumer := kafka.NewConsumer(brokers, kafka.TopicDriverEvents, "notification-service")
	eventhandlers.RegisterDriverHandlers(driverConsumer)
	logger.Printf("🧑‍✈️ Driver event consumer registered (topic: %s)", kafka.TopicDriverEvents)

	// Start consumers in goroutines
	go func() {
		logger.Println("📦 Order consumer listening...")
		if err := orderConsumer.Listen(ctx); err != nil {
			logger.Printf("Order consumer stopped: %v", err)
		}
	}()

	go func() {
		logger.Println("🚗 Ride consumer listening...")
		if err := rideConsumer.Listen(ctx); err != nil {
			logger.Printf("Ride consumer stopped: %v", err)
		}
	}()

	go func() {
		logger.Println("🧑‍✈️ Driver consumer listening...")
		if err := driverConsumer.Listen(ctx); err != nil {
			logger.Printf("Driver consumer stopped: %v", err)
		}
	}()

	// ==========================================
	// HTTP Health Check Server
	// ==========================================
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"ok","service":"notification-service","consumers":["order.events","ride.events","driver.events"]}`)
	})

	httpServer := &http.Server{
		Addr:    ":" + cfg.HTTPPort,
		Handler: mux,
	}

	go func() {
		logger.Printf("🌐 HTTP health server on :%s", cfg.HTTPPort)
		if err := httpServer.ListenAndServe(); err != http.ErrServerClosed {
			logger.Fatalf("HTTP serve failed: %v", err)
		}
	}()

	logger.Println("✅ Notification service started — listening for events")

	// ==========================================
	// Graceful Shutdown
	// ==========================================
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Println("Shutting down...")
	cancel()
	orderConsumer.Close()
	rideConsumer.Close()
	driverConsumer.Close()
	httpServer.Close()
	logger.Println("Stopped ✅")
}

type Config struct {
	HTTPPort     string
	KafkaBrokers string
}

func loadConfig() Config {
	return Config{
		HTTPPort:     getEnv("HTTP_PORT", "8092"),
		KafkaBrokers: getEnv("KAFKA_BROKERS", "localhost:9092"),
	}
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
