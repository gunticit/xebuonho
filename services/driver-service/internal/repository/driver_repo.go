package repository

import (
	"context"
	"fmt"
	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/services/driver-service/internal/model"
)

type DriverRepository interface {
	UpdateStatus(ctx context.Context, driverID, status string) error
	GetDriver(ctx context.Context, driverID string) (*model.Driver, error)
	SetCurrentRide(ctx context.Context, driverID, rideID string) error
}

type postgresDriverRepo struct {
	db *database.PostgresDB
}

func NewDriverRepository(db *database.PostgresDB) DriverRepository {
	return &postgresDriverRepo{db: db}
}

func (r *postgresDriverRepo) UpdateStatus(ctx context.Context, driverID, status string) error {
	query := `UPDATE users SET status = $1 WHERE id = $2`
	return r.db.Exec(ctx, query, status, driverID)
}

func (r *postgresDriverRepo) GetDriver(ctx context.Context, driverID string) (*model.Driver, error) {
	var d model.Driver
	query := `SELECT id, name, phone, status FROM users WHERE id = $1`
	err := r.db.QueryRow(ctx, query, driverID).Scan(&d.ID, &d.Name, &d.Phone, &d.Status)
	if err != nil {
		return nil, fmt.Errorf("get driver: %w", err)
	}
	return &d, nil
}

func (r *postgresDriverRepo) SetCurrentRide(ctx context.Context, driverID, rideID string) error {
	query := `UPDATE driver_capabilities SET current_ride_id = $1 WHERE driver_id = $2`
	return r.db.Exec(ctx, query, rideID, driverID)
}
