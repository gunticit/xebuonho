# ==============================================
# Multi-stage Dockerfile for Go microservices
# Usage: docker build --build-arg SERVICE=ride-service -t xebuonho/ride-service .
# ==============================================

# Stage 1: Build
FROM golang:1.22-alpine AS builder

ARG SERVICE

RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy workspace files
COPY go.work go.work.sum* ./
COPY pkg/ ./pkg/
COPY services/${SERVICE}/ ./services/${SERVICE}/

# Download dependencies
RUN cd services/${SERVICE} && go mod download
RUN cd pkg && go mod download

# Build the binary
RUN cd services/${SERVICE} && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /app/bin/service ./cmd/main.go

# Stage 2: Runtime (minimal image)
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

# Set timezone to Vietnam
ENV TZ=Asia/Ho_Chi_Minh

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/bin/service .

# Copy migrations if they exist
ARG SERVICE
COPY --from=builder /app/services/${SERVICE}/migrations/ ./migrations/ 2>/dev/null || true

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 8080 50051

ENTRYPOINT ["./service"]
