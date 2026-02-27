package database

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
)

// ConnectRedis creates a Redis client connection
func ConnectRedis(ctx context.Context, redisURL string) (*redis.Client, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		// Fallback: treat as host:port
		opts = &redis.Options{
			Addr:     redisURL,
			DB:       0,
			PoolSize: 20,
		}
	}

	client := redis.NewClient(opts)
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("ping redis: %w", err)
	}

	return client, nil
}
