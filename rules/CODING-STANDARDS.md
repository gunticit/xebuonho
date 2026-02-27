# 📏 Coding Standards - XeBuonHo

## Ngôn ngữ: Go (Backend Services)

### Project Structure (mỗi service)

```
services/ride-service/
├── cmd/
│   └── main.go              # Entry point
├── internal/
│   ├── handler/              # HTTP/gRPC handlers
│   │   ├── ride_handler.go
│   │   └── health_handler.go
│   ├── service/              # Business logic
│   │   ├── ride_service.go
│   │   └── ride_service_test.go
│   ├── repository/           # Data access
│   │   ├── ride_repo.go
│   │   └── ride_repo_test.go
│   ├── model/                # Domain models
│   │   ├── ride.go
│   │   └── status.go
│   └── config/               # Configuration
│       └── config.go
├── migrations/               # DB migrations
├── go.mod
├── go.sum
├── Dockerfile
└── Makefile
```

### Naming Conventions

```go
// ✅ Package names: lowercase, single word
package ride       // Good
package rideService // Bad

// ✅ Exported functions: PascalCase + tên rõ ràng
func CreateRide(ctx context.Context, req CreateRideRequest) (*Ride, error) {}
func FindNearbyDrivers(lat, lng float64, radiusKm float64) ([]Driver, error) {}

// ✅ Unexported functions: camelCase
func calculateFare(distance float64, duration time.Duration) float64 {}

// ✅ Interface names: thêm -er suffix nếu 1 method
type RideCreator interface {
    CreateRide(ctx context.Context, req CreateRideRequest) (*Ride, error)
}

// ✅ Error variables: Err prefix
var (
    ErrRideNotFound     = errors.New("ride not found")
    ErrInvalidTransition = errors.New("invalid state transition")
    ErrDriverBusy       = errors.New("driver is busy")
)

// ✅ Constants: PascalCase
const (
    MaxSearchRadius     = 5.0  // km
    DriverResponseTimeout = 30 * time.Second
    DefaultPageSize     = 20
)
```

### Code Quality Rules

```go
// ✅ RULE 1: Always use context.Context as first parameter
func (s *RideService) GetRide(ctx context.Context, id string) (*Ride, error) {}

// ✅ RULE 2: Always return error as last return value
func (s *RideService) CreateRide(ctx context.Context, req Request) (*Ride, error) {}

// ✅ RULE 3: Use struct for 3+ parameters
// ❌ Bad
func CreateRide(ctx context.Context, riderID, pickup, dropoff string, vehicleType string) {}
// ✅ Good
func CreateRide(ctx context.Context, req CreateRideRequest) (*Ride, error) {}

// ✅ RULE 4: Validate input at handler level
func (h *RideHandler) CreateRide(ctx context.Context, req *pb.CreateRideRequest) error {
    if err := validateCreateRideRequest(req); err != nil {
        return status.Errorf(codes.InvalidArgument, "invalid request: %v", err)
    }
    // ...
}

// ✅ RULE 5: Use defer for cleanup
func (s *Service) ProcessRide(ctx context.Context) error {
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback() // Always rollback unless committed
    
    // ... do work ...
    
    return tx.Commit()
}
```

### Testing Standards

```go
// ✅ Table-driven tests
func TestCalculateFare(t *testing.T) {
    tests := []struct {
        name        string
        vehicleType string
        distanceKm  float64
        durationMin int
        wantFare    float64
    }{
        {
            name: "short bike ride",
            vehicleType: "bike", distanceKm: 1.5, durationMin: 5,
            wantFare: 15000,
        },
        {
            name: "long car ride",
            vehicleType: "car", distanceKm: 15.0, durationMin: 30,
            wantFare: 175000,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := CalculateFare(tt.vehicleType, tt.distanceKm, tt.durationMin, 1.0, 0, 0)
            assert.Equal(t, tt.wantFare, got.TotalFare)
        })
    }
}
```

### Linting & Formatting

```makefile
# Makefile
.PHONY: lint
lint:
	golangci-lint run ./...

.PHONY: fmt
fmt:
	gofmt -s -w .
	goimports -w .

.PHONY: test
test:
	go test -v -race -coverprofile=coverage.out ./...
```

---

## Commit Convention

```
feat(ride): add idempotency check for ride creation
fix(location): handle nil pointer in GPS update
refactor(payment): extract fare calculation logic
docs(arch): update communication layer diagram
test(matching): add unit tests for nearby driver search
chore(deps): update go-redis to v9.3.0
```
