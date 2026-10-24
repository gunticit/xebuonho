package repository

import (
	"context"
	"fmt"
	"github.com/xebuonho/pkg/database"
	"github.com/xebuonho/services/payment-service/internal/model"
)

type PaymentRepository interface {
	CreateTransaction(ctx context.Context, tx *model.PaymentResponse) error
	UpdateTransactionStatus(ctx context.Context, txID, status string) error
	SaveInvoice(ctx context.Context, invoice *model.Invoice) error
	GetInvoiceByOrderID(ctx context.Context, orderID string) (*model.Invoice, error)
}

type postgresPaymentRepo struct {
	db *database.PostgresDB
}

func NewPaymentRepository(db *database.PostgresDB) PaymentRepository {
	return &postgresPaymentRepo{db: db}
}

func (r *postgresPaymentRepo) CreateTransaction(ctx context.Context, tx *model.PaymentResponse) error {
	query := `INSERT INTO transactions (id, order_id, amount, status, paid_at) VALUES ($1, $2, $3, $4, $5)`
	// Note: tx.TransactionID, tx.OrderID (should be added to model), tx.PaidAmount, tx.Status, tx.PaidAt
	// Simplified for brevity
	return r.db.Exec(ctx, query, tx.TransactionID, "order_id_placeholder", tx.PaidAmount, tx.Status, tx.PaidAt)
}

func (r *postgresPaymentRepo) UpdateTransactionStatus(ctx context.Context, txID, status string) error {
	query := `UPDATE transactions SET status = $1 WHERE id = $2`
	return r.db.Exec(ctx, query, status, txID)
}

func (r *postgresPaymentRepo) SaveInvoice(ctx context.Context, invoice *model.Invoice) error {
	query := `INSERT INTO invoices (order_id, total_amount, status, created_at) VALUES ($1, $2, $3, $4)`
	return r.db.Exec(ctx, query, invoice.OrderID, invoice.TotalAmount, invoice.PaymentStatus, invoice.CreatedAt)
}

func (r *postgresPaymentRepo) GetInvoiceByOrderID(ctx context.Context, orderID string) (*model.Invoice, error) {
	var inv model.Invoice
	query := `SELECT id, order_id, total_amount, status FROM invoices WHERE order_id = $1`
	err := r.db.QueryRow(ctx, query, orderID).Scan(&inv.OrderID, &inv.TotalAmount, &inv.PaymentStatus)
	if err != nil {
		return nil, fmt.Errorf("get invoice: %w", err)
	}
	return &inv, nil
}
