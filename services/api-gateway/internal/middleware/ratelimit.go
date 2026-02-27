package middleware

import (
	"net/http"
	"sync"
	"time"
)

// RateLimiter implements a simple sliding window rate limiter per IP
type RateLimiter struct {
	mu       sync.Mutex
	clients  map[string]*clientWindow
	limit    int
	windowMs int64
}

type clientWindow struct {
	count       int
	windowStart int64
}

// NewRateLimiter creates a rate limiter (requests per second)
func NewRateLimiter(requestsPerSecond int) *RateLimiter {
	return &RateLimiter{
		clients:  make(map[string]*clientWindow),
		limit:    requestsPerSecond,
		windowMs: 1000,
	}
}

// RateLimitMiddleware applies rate limiting per IP
func (rl *RateLimiter) RateLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ip := r.RemoteAddr
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			ip = forwarded
		}

		rl.mu.Lock()
		now := time.Now().UnixMilli()
		client, exists := rl.clients[ip]
		if !exists || now-client.windowStart > rl.windowMs {
			rl.clients[ip] = &clientWindow{count: 1, windowStart: now}
			rl.mu.Unlock()
			next.ServeHTTP(w, r)
			return
		}

		if client.count >= rl.limit {
			rl.mu.Unlock()
			w.Header().Set("Retry-After", "1")
			writeError(w, http.StatusTooManyRequests, "rate limit exceeded")
			return
		}

		client.count++
		rl.mu.Unlock()
		next.ServeHTTP(w, r)
	})
}

// CORSMiddleware handles Cross-Origin Resource Sharing
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Request-ID, X-Idempotency-Key")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// LoggingMiddleware logs each request
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(wrapped, r)

		// Log format: [METHOD] /path STATUS DURATIONms
		_ = start // In production: logger.Info(...)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}
