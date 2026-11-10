package handler_test

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/xebuonho/services/trip-service/internal/handler"
	"github.com/xebuonho/services/trip-service/internal/model"
	"github.com/xebuonho/services/trip-service/internal/service"
)

type mockServiceRepo struct {
	trips      []model.Trip
	total      int
	customerID string
	driverID   string
	status     string
	summary    *model.RatingSummary
}

func (m *mockServiceRepo) ListTrips(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]model.Trip, int, error) {
	return m.trips, m.total, nil
}

func (m *mockServiceRepo) GetTrip(ctx context.Context, tripID, userID string) (*model.Trip, error) {
	return &model.Trip{ID: tripID, CustomerID: userID, ServiceType: "ride", Status: "completed"}, nil
}

func (m *mockServiceRepo) GetOrderParticipants(ctx context.Context, tripID string) (string, string, string, error) {
	return m.customerID, m.driverID, m.status, nil
}

func (m *mockServiceRepo) UpsertRating(ctx context.Context, orderID, customerID, driverID, ratedBy, ratedRole string, rating int, tipAmount float64, comment string) error {
	return nil
}

func (m *mockServiceRepo) GetRatingSummary(ctx context.Context, driverID string) (*model.RatingSummary, error) {
	if m.summary != nil {
		return m.summary, nil
	}
	return &model.RatingSummary{DriverID: driverID, AverageRating: 5.0, TotalRatings: 10}, nil
}

func makeTestJWT(userID, role, secret string, expDelta time.Duration) string {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	payloadObj := map[string]interface{}{
		"user_id": userID,
		"role":    role,
		"exp":     time.Now().Add(expDelta).Unix(),
		"iat":     time.Now().Unix(),
	}
	payloadBytes, _ := json.Marshal(payloadObj)
	payload := base64.RawURLEncoding.EncodeToString(payloadBytes)

	signingInput := header + "." + payload
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signingInput))
	sig := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))

	return signingInput + "." + sig
}

func setupTestMux(repo service.Repository, jwtSecret string) *http.ServeMux {
	svc := service.NewTripService(repo)
	h := handler.NewTripHandler(svc, jwtSecret)
	mux := http.NewServeMux()
	h.Register(mux)
	return mux
}

func TestHTTPHandler_ListTrips_Auth(t *testing.T) {
	secret := "test-secret"
	repo := &mockServiceRepo{
		trips: []model.Trip{{ID: "t-1", ServiceType: "ride", Status: "completed"}},
		total: 1,
	}
	mux := setupTestMux(repo, secret)

	// 1. Without Auth
	req := httptest.NewRequest(http.MethodGet, "/trips", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 without auth, got %d", rec.Code)
	}

	// 2. With valid JWT on /trips
	token := makeTestJWT("user-1", "rider", secret, time.Hour)
	req = httptest.NewRequest(http.MethodGet, "/trips?service_type=ride", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 with valid JWT, got %d: %s", rec.Code, rec.Body.String())
	}

	// 3. With /api/v1/trips prefix
	req = httptest.NewRequest(http.MethodGet, "/api/v1/trips?service_type=ride", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec = httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 with /api/v1/trips prefix, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestHTTPHandler_GetTrip_And_Rating(t *testing.T) {
	secret := "test-secret"
	repo := &mockServiceRepo{
		customerID: "user-1",
		driverID:   "driver-1",
		status:     "completed",
	}
	mux := setupTestMux(repo, secret)
	token := makeTestJWT("user-1", "rider", secret, time.Hour)

	// GET /api/v1/trips/trip-123
	req := httptest.NewRequest(http.MethodGet, "/api/v1/trips/trip-123", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /api/v1/trips/trip-123 failed with code %d: %s", rec.Code, rec.Body.String())
	}

	// POST /api/v1/trips/trip-123/rating
	body := bytes.NewBufferString(`{"rating":5,"tip_amount":20000,"comment":"Tuyệt vời"}`)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/trips/trip-123/rating", body)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	rec = httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /api/v1/trips/trip-123/rating failed with code %d: %s", rec.Code, rec.Body.String())
	}

	// GET /api/v1/drivers/driver-1/rating-summary (public endpoint)
	req = httptest.NewRequest(http.MethodGet, "/api/v1/drivers/driver-1/rating-summary", nil)
	rec = httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /api/v1/drivers/driver-1/rating-summary failed with code %d: %s", rec.Code, rec.Body.String())
	}
}

func TestHTTPHandler_ExpiredToken(t *testing.T) {
	secret := "test-secret"
	mux := setupTestMux(&mockServiceRepo{}, secret)

	expiredToken := makeTestJWT("user-1", "rider", secret, -time.Hour)
	req := httptest.NewRequest(http.MethodGet, "/trips", nil)
	req.Header.Set("Authorization", "Bearer "+expiredToken)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for expired token, got %d", rec.Code)
	}
}

