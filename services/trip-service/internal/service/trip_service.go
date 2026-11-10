package service

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"

	"github.com/xebuonho/services/trip-service/internal/model"
)

var validServiceTypes = map[string]bool{
	"ride":              true,
	"food_delivery":     true,
	"grocery":           true,
	"designated_driver": true,
}

type Repository interface {
	ListTrips(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]model.Trip, int, error)
	GetTrip(ctx context.Context, tripID, userID string) (*model.Trip, error)
	GetOrderParticipants(ctx context.Context, tripID string) (customerID, driverID, status string, err error)
	UpsertRating(ctx context.Context, orderID, customerID, driverID, ratedBy, ratedRole string, rating int, tipAmount float64, comment string) error
	GetRatingSummary(ctx context.Context, driverID string) (*model.RatingSummary, error)
}

type TripService struct {
	repo Repository
}

func NewTripService(repo Repository) *TripService {
	return &TripService{repo: repo}
}

// ListTrips returns finished trips for the given user.
func (s *TripService) ListTrips(ctx context.Context, userID, role, serviceType string, page, pageSize int) ([]model.Trip, int, error) {
	if role != "rider" && role != "driver" {
		role = "rider"
	}
	if serviceType != "" && !validServiceTypes[serviceType] {
		return nil, 0, fmt.Errorf("invalid service_type %q", serviceType)
	}
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 50 {
		pageSize = 20
	}
	return s.repo.ListTrips(ctx, userID, role, serviceType, page, pageSize)
}

// GetTrip returns a single trip the user participates in.
func (s *TripService) GetTrip(ctx context.Context, tripID, userID string) (*model.Trip, error) {
	if tripID == "" {
		return nil, fmt.Errorf("trip id is required")
	}
	trip, err := s.repo.GetTrip(ctx, tripID, userID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("trip not found")
		}
		return nil, err
	}
	return trip, nil
}

// SubmitRating records a rating for a completed trip. Only participants may rate,
// and only rateable (non-cancelled) trips can be rated.
func (s *TripService) SubmitRating(ctx context.Context, tripID, userID string, req model.SubmitRatingRequest) error {
	if req.Rating < 1 || req.Rating > 5 {
		return fmt.Errorf("rating must be between 1 and 5")
	}

	customerID, driverID, status, err := s.repo.GetOrderParticipants(ctx, tripID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("trip not found")
		}
		return err
	}

	if userID != customerID && userID != driverID {
		return fmt.Errorf("only trip participants can submit a rating")
	}

	switch status {
	case "completed", "paid", "delivered":
		// rateable
	default:
		return fmt.Errorf("trip with status %q cannot be rated", status)
	}

	ratedRole := "rider"
	if userID == driverID && userID != customerID {
		ratedRole = "driver"
	}

	return s.repo.UpsertRating(ctx, tripID, customerID, driverID, userID, ratedRole, req.Rating, req.TipAmount, req.Comment)
}

// GetRatingSummary returns aggregated customer ratings for a driver.
func (s *TripService) GetRatingSummary(ctx context.Context, driverID string) (*model.RatingSummary, error) {
	if driverID == "" {
		return nil, fmt.Errorf("driver id is required")
	}
	return s.repo.GetRatingSummary(ctx, driverID)
}
