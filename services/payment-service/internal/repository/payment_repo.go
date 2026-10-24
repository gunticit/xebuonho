package repository

import (
	"context"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xebuonho/services/payment-service/internal/model"
)

type PaymentRepository interface {
	CreateTransaction(ctx context.Context, tx *model.PaymentResponse) error
	UpdateTransactionStatus(ctx context.Context, txID, status string) error
	SaveInvoice(ctx context.Context, invoice *model.Invoice) error
	GetInvoiceByOrderID(ctx context.Context, orderID string) (*model.Invoice, error)
}

type postgresPaymentRepo struct {
	db *pgxpool.Pool
}

func NewPaymentRepository(db *pgxpool.Pool) PaymentRepository {
	return &postgresPaymentRepo{db: db}
}

func (r *postgresPaymentRepo) CreateTransaction(ctx context.Context, tx *model.PaymentResponse) error {
	query := `INSERT INTO transactions (id, order_id, amount, status, paid_at) VALUES ($1, $2, $3, $4, $5)`
	_, err := r.db.Exec(ctx, query, tx.TransactionID, "order_id_placeholder", tx.PaidAmount, tx.Status, tx.PaidAt)
	return err
}

func (r *postgresPaymentRepo) UpdateTransactionStatus(ctx context.Context, txID, status string) error {
	query := `UPDATE transactions SET status = $1 WHERE id = $2`
	_, err := r.db.Exec(ctx, query, status, txID)
	return err
}

func (r *postgresPaymentRepo) SaveInvoice(ctx context.Context, invoice *model.Invoice) error {
	query := `INSERT INTO invoices (order_id, total_amount, status, created_at) VALUES ($1, $2, $3, $4)`
	_, err := r.db.Exec(ctx, query, invoice.OrderID, invoice.TotalAmount, invoice.PaymentStatus, invoice.CreatedAt)
	return err
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
