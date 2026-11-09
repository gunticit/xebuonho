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

	// Wallet Operations
	GetWalletByUserID(ctx context.Context, userID string) (*model.Wallet, error)
	CreateWalletIfNotExist(ctx context.Context, userID string) (*model.Wallet, error)
	AtomicDeductWallet(ctx context.Context, userID string, amount float64, txType, refID, notes string) (*model.Wallet, error)
	CreditWallet(ctx context.Context, userID string, amount float64, txType, refID, notes string) (*model.Wallet, error)
	GetWalletTransactions(ctx context.Context, userID string, limit, offset int) ([]model.WalletTransaction, error)
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

func (r *postgresPaymentRepo) GetWalletByUserID(ctx context.Context, userID string) (*model.Wallet, error) {
	var w model.Wallet
	query := `SELECT id, user_id, balance, currency, is_locked, created_at, updated_at FROM wallets WHERE user_id = $1`
	err := r.db.QueryRow(ctx, query, userID).Scan(&w.ID, &w.UserID, &w.Balance, &w.Currency, &w.IsLocked, &w.CreatedAt, &w.UpdatedAt)
	if err != nil {
		// If wallet does not exist, initialize it
		return r.CreateWalletIfNotExist(ctx, userID)
	}
	return &w, nil
}

func (r *postgresPaymentRepo) CreateWalletIfNotExist(ctx context.Context, userID string) (*model.Wallet, error) {
	var w model.Wallet
	query := `
		INSERT INTO wallets (user_id, balance, currency, is_locked)
		VALUES ($1, 0.00, 'VND', false)
		ON CONFLICT (user_id) DO UPDATE SET updated_at = NOW()
		RETURNING id, user_id, balance, currency, is_locked, created_at, updated_at
	`
	err := r.db.QueryRow(ctx, query, userID).Scan(&w.ID, &w.UserID, &w.Balance, &w.Currency, &w.IsLocked, &w.CreatedAt, &w.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("create wallet: %w", err)
	}
	return &w, nil
}

// AtomicDeductWallet deducts balance safely with WHERE balance >= amount check to prevent overdraft / race condition
func (r *postgresPaymentRepo) AtomicDeductWallet(ctx context.Context, userID string, amount float64, txType, refID, notes string) (*model.Wallet, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var w model.Wallet
	deductQuery := `
		UPDATE wallets
		SET balance = balance - $1, updated_at = NOW()
		WHERE user_id = $2 AND balance >= $1 AND is_locked = false
		RETURNING id, user_id, balance, currency, is_locked, created_at, updated_at
	`
	err = tx.QueryRow(ctx, deductQuery, amount, userID).Scan(&w.ID, &w.UserID, &w.Balance, &w.Currency, &w.IsLocked, &w.CreatedAt, &w.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("insufficient balance or locked wallet: %w", err)
	}

	// Insert audit record in wallet_transactions
	logQuery := `
		INSERT INTO wallet_transactions (wallet_id, user_id, amount, type, reference_id, notes)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err = tx.Exec(ctx, logQuery, w.ID, userID, -amount, txType, refID, notes)
	if err != nil {
		return nil, fmt.Errorf("log wallet transaction: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &w, nil
}

// CreditWallet adds funds to a user wallet atomically
func (r *postgresPaymentRepo) CreditWallet(ctx context.Context, userID string, amount float64, txType, refID, notes string) (*model.Wallet, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// Ensure wallet exists
	_, _ = r.CreateWalletIfNotExist(ctx, userID)

	var w model.Wallet
	creditQuery := `
		UPDATE wallets
		SET balance = balance + $1, updated_at = NOW()
		WHERE user_id = $2
		RETURNING id, user_id, balance, currency, is_locked, created_at, updated_at
	`
	err = tx.QueryRow(ctx, creditQuery, amount, userID).Scan(&w.ID, &w.UserID, &w.Balance, &w.Currency, &w.IsLocked, &w.CreatedAt, &w.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("credit wallet: %w", err)
	}

	logQuery := `
		INSERT INTO wallet_transactions (wallet_id, user_id, amount, type, reference_id, notes)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err = tx.Exec(ctx, logQuery, w.ID, userID, amount, txType, refID, notes)
	if err != nil {
		return nil, fmt.Errorf("log wallet transaction: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &w, nil
}

func (r *postgresPaymentRepo) GetWalletTransactions(ctx context.Context, userID string, limit, offset int) ([]model.WalletTransaction, error) {
	if limit <= 0 {
		limit = 20
	}
	query := `
		SELECT id, wallet_id, user_id, amount, type, COALESCE(reference_id, ''), COALESCE(notes, ''), created_at
		FROM wallet_transactions
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var txs []model.WalletTransaction
	for rows.Next() {
		var t model.WalletTransaction
		if err := rows.Scan(&t.ID, &t.WalletID, &t.UserID, &t.Amount, &t.Type, &t.ReferenceID, &t.Notes, &t.CreatedAt); err != nil {
			return nil, err
		}
		txs = append(txs, t)
	}
	return txs, nil
}
