package config

import (
	"os"
)

type Config struct {
	ServiceName  string
	HTTPPort     string
	GRPCPort     string
	DatabaseURL  string
	RedisURL     string
	KafkaBrokers string
	JWTSecret    string
	LogLevel     string
}

func LoadConfig() Config {
	return Config{
		ServiceName:  "driver-service",
		HTTPPort:     getEnv("HTTP_PORT", "8081"),
		GRPCPort:     getEnv("GRPC_PORT", "50052"),
		DatabaseURL:  getEnv("DATABASE_URL", "postgresql://app:secret@localhost:5432/xebuonho?sslmode=disable"),
		RedisURL:     getEnv("REDIS_URL", "localhost:6379"),
		KafkaBrokers: getEnv("KAFKA_BROKERS", "localhost:9092"),
		JWTSecret:    getEnv("JWT_SECRET", "dev-secret"),
		LogLevel:     getEnv("LOG_LEVEL", "info"),
	}
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
