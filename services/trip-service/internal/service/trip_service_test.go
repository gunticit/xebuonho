package service_test

import (
	"context"
	"errors"
	"testing"

	"github.com/xebuonho/services/trip-service/internal/model"
	"github.com/xebuonho/services/trip-service/internal/service"
)

type mockRepo struct {
	trips           []model.Trip
	total           int
	getTripErr      error
	customerID      string
	driverID        string
	orderStatus     string
	participantErr  error
	upsertCalled    bool
	lastRatedRole   string
	lastRating      int
	lastTipAmount   float64
	summary         *model.RatingSummary
	summaryErr      error
}

func (m *mockRepo) ListTrips(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]model.Trip, int, error) {
	return m.trips, m.total, nil
}

func (m *mockRepo) GetTrip(ctx context.Context, tripID, userID string) (*model.Trip, error) {
	if m.getTripErr != nil {
		return nil, m.getTripErr
	}
	return &model.Trip{ID: tripID, CustomerID: userID}, nil
}

func (m *mockRepo) GetOrderParticipants(ctx context.Context, tripID string) (string, string, string, error) {
	if m.participantErr != nil {
		return "", "", "", m.participantErr
	}
	return m.customerID, m.driverID, m.orderStatus, nil
}

func (m *mockRepo) UpsertRating(ctx context.Context, orderID, customerID, driverID, ratedBy, ratedRole string, rating int, tipAmount float64, comment string) error {
	m.upsertCalled = true
	m.lastRatedRole = ratedRole
	m.lastRating = rating
	m.lastTipAmount = tipAmount
	return nil
}

func (m *mockRepo) GetRatingSummary(ctx context.Context, driverID string) (*model.RatingSummary, error) {
	if m.summaryErr != nil {
		return nil, m.summaryErr
	}
	return m.summary, nil
}

func TestSubmitRating_Validation(t *testing.T) {
	tests := []struct {
		name          string
		rating        int
		customerID    string
		driverID      string
		orderStatus   string
		userID        string
		wantErr       bool
		expectedRole  string
	}{
		{
			name:        "rating 0 is invalid",
			rating:      0,
			customerID:  "user-1",
			driverID:    "driver-1",
			orderStatus: "completed",
			userID:      "user-1",
			wantErr:     true,
		},
		{
			name:        "rating 6 is invalid",
			rating:      6,
			customerID:  "user-1",
			driverID:    "driver-1",
			orderStatus: "completed",
			userID:      "user-1",
			wantErr:     true,
		},
		{
			name:        "non-participant cannot rate",
			rating:      5,
			customerID:  "user-1",
			driverID:    "driver-1",
			orderStatus: "completed",
			userID:      "intruder-99",
			wantErr:     true,
		},
		{
			name:        "cancelled order cannot be rated",
			rating:      5,
			customerID:  "user-1",
			driverID:    "driver-1",
			orderStatus: "cancelled",
			userID:      "user-1",
			wantErr:     true,
		},
		{
			name:        "in_progress order cannot be rated",
			rating:      5,
			customerID:  "user-1",
			driverID:    "driver-1",
			orderStatus: "moving",
			userID:      "user-1",
			wantErr:     true,
		},
		{
			name:         "rider rating completed order is valid",
			rating:       5,
			customerID:   "user-1",
			driverID:     "driver-1",
			orderStatus:  "completed",
			userID:       "user-1",
			wantErr:      false,
			expectedRole: "rider",
		},
		{
			name:         "driver rating delivered order is valid",
			rating:       4,
			customerID:   "user-1",
			driverID:     "driver-1",
			orderStatus:  "delivered",
			userID:       "driver-1",
			wantErr:      false,
			expectedRole: "driver",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mock := &mockRepo{
				customerID:  tt.customerID,
				driverID:    tt.driverID,
				orderStatus: tt.orderStatus,
			}
			svc := service.NewTripService(mock)

			err := svc.SubmitRating(context.Background(), "order-123", tt.userID, model.SubmitRatingRequest{
				Rating:    tt.rating,
				TipAmount: 10000,
				Comment:   "Good service",
			})

			if (err != nil) != tt.wantErr {
				t.Fatalf("SubmitRating() error = %v, wantErr = %v", err, tt.wantErr)
			}

			if !tt.wantErr {
				if !mock.upsertCalled {
					t.Errorf("expected UpsertRating to be called")
				}
				if mock.lastRatedRole != tt.expectedRole {
					t.Errorf("expected ratedRole = %s, got %s", tt.expectedRole, mock.lastRatedRole)
				}
				if mock.lastRating != tt.rating {
					t.Errorf("expected rating = %d, got %d", tt.rating, mock.lastRating)
				}
			}
		})
	}
}

func TestListTrips(t *testing.T) {
	mock := &mockRepo{
		trips: []model.Trip{
			{ID: "trip-1", ServiceType: "ride", Status: "completed"},
		},
		total: 1,
	}
	svc := service.NewTripService(mock)

	// Valid query
	trips, total, err := svc.ListTrips(context.Background(), "user-1", "rider", "ride", 1, 10)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(trips) != 1 || total != 1 {
		t.Errorf("expected 1 trip, got %d (total %d)", len(trips), total)
	}

	// Invalid service type
	_, _, err = svc.ListTrips(context.Background(), "user-1", "rider", "invalid_type", 1, 10)
	if err == nil {
		t.Errorf("expected error for invalid service type")
	}
}

func TestGetTrip_Validation(t *testing.T) {
	svc := service.NewTripService(&mockRepo{})

	_, err := svc.GetTrip(context.Background(), "", "user-1")
	if err == nil {
		t.Errorf("expected error when trip id is empty")
	}

	trip, err := svc.GetTrip(context.Background(), "t-1", "user-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if trip.ID != "t-1" {
		t.Errorf("expected trip id 't-1', got %s", trip.ID)
	}
}

func TestGetRatingSummary_Validation(t *testing.T) {
	mock := &mockRepo{
		summary: &model.RatingSummary{
			DriverID:      "driver-1",
			AverageRating: 4.8,
			TotalRatings:  25,
			TotalTips:     50000,
		},
	}
	svc := service.NewTripService(mock)

	_, err := svc.GetRatingSummary(context.Background(), "")
	if err == nil {
		t.Errorf("expected error when driver id is empty")
	}

	summary, err := svc.GetRatingSummary(context.Background(), "driver-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if summary.AverageRating != 4.8 || summary.TotalRatings != 25 {
		t.Errorf("unexpected summary data: %+v", summary)
	}
}

func TestGetTrip_NotFound(t *testing.T) {
	mock := &mockRepo{
		getTripErr: errors.New("trip not found"),
	}
	svc := service.NewTripService(mock)

	_, err := svc.GetTrip(context.Background(), "t-unknown", "user-1")
	if err == nil {
		t.Errorf("expected error for unknown trip")
	}
}

