package config

import (
	"os"
	"strconv"
)

// Config holds runtime configuration for matching-service
type Config struct {
	ServiceName     string
	HTTPPort        string
	GRPCPort        string
	RedisURL        string
	KafkaBrokers    string
	InitialRadiusKm float64
	FallbackRadiusKm float64
	MaxRetries      int
	WeightDistance  float64
	WeightRating    float64
	WeightWaitTime  float64
}

// LoadConfig loads configuration from environment variables with fallbacks
func LoadConfig() *Config {
	return &Config{
		ServiceName:      getEnv("SERVICE_NAME", "matching-service"),
		HTTPPort:         getEnv("HTTP_PORT", "8082"),
		GRPCPort:         getEnv("GRPC_PORT", "50052"),
		RedisURL:         getEnv("REDIS_URL", "localhost:6379"),
		KafkaBrokers:     getEnv("KAFKA_BROKERS", "localhost:9092"),
		InitialRadiusKm:  getEnvFloat("INITIAL_RADIUS_KM", 2.0),
		FallbackRadiusKm: getEnvFloat("FALLBACK_RADIUS_KM", 5.0),
		MaxRetries:       getEnvInt("MAX_RETRIES", 3),
		WeightDistance:   getEnvFloat("WEIGHT_DISTANCE", 0.4),
		WeightRating:     getEnvFloat("WEIGHT_RATING", 0.3),
		WeightWaitTime:   getEnvFloat("WEIGHT_WAIT_TIME", 0.3),
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvFloat(key string, fallback float64) float64 {
	val := os.Getenv(key)
	if val == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(val, 64)
	if err != nil {
		return fallback
	}
	return f
}

func getEnvInt(key string, fallback int) int {
	val := os.Getenv(key)
	if val == "" {
		return fallback
	}
	n, err := strconv.Atoi(val)
	if err != nil {
		return fallback
	}
	return n
}
