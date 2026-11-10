package config

import "os"

type Config struct {
	ServiceName string
	HTTPPort    string
	GRPCPort    string
	DatabaseURL string
	JWTSecret   string
}

func LoadConfig() *Config {
	return &Config{
		ServiceName: getEnv("SERVICE_NAME", "trip-service"),
		HTTPPort:    getEnv("HTTP_PORT", "8086"),
		GRPCPort:    getEnv("GRPC_PORT", "50057"),
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
