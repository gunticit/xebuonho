package model

import "time"

type PaymentMethod string

const (
	PaymentMethodCash    PaymentMethod = "cash"
	PaymentMethodWallet  PaymentMethod = "wallet"
	PaymentMethodCard    PaymentMethod = "card"
	PaymentMethodQR      PaymentMethod = "qr"
)

type TransactionStatus string

const (
	TxStatusPending   TransactionStatus = "pending"
	TxStatusCompleted  TransactionStatus = "completed"
	TxStatusFailed     TransactionStatus = "failed"
	TxStatusRefunded  TransactionStatus = "refunded"
)

type PaymentRequest struct {
	OrderID       string  `json:"order_id"`
	CustomerID   string  `json:"customer_id"`
	Amount        float64 `json:"amount"`
	PaymentMethod PaymentMethod `json:"payment_method"`
}

type PaymentResponse struct {
	TransactionID string            `json:"transaction_id"`
	Status        TransactionStatus `json:"status"`
	PaidAmount    float64           `json:"paid_amount"`
	PaidAt        time.Time         `json:"paid_at"`
	QRUrl        string            `json:"qr_url,omitempty"`
	TransferNote string            `json:"transfer_note,omitempty"`
}

type SePayWebhookPayload struct {
	TransactionID string    `json:"transaction_id"`
	Amount        float64   `json:"amount"`
	Content       string    `json:"content"`
	BankCode      string    `json:"bank_code"`
	AccountName   string    `json:"account_name"`
	CreatedAt     time.Time  `json:"created_at"`
}

type Invoice struct {
	OrderID        string            `json:"order_id"`
	InvoiceNumber  string            `json:"invoice_number,omitempty"`
	TaxCode        string            `json:"tax_code,omitempty"`
	BuyerName      string            `json:"buyer_name,omitempty"`
	BaseFare       float64           `json:"base_fare"`
	DistanceFare   float64           `json:"distance_fare"`
	TimeFare       float64           `json:"time_fare"`
	SurgeAmount    float64           `json:"surge_amount"`
	PlatformFee    float64           `json:"platform_fee"`
	Discount       float64           `json:"discount"`
	TotalAmount    float64           `json:"total_amount"`
	VATAmt         float64           `json:"vat_amount,omitempty"`
	PaymentStatus  TransactionStatus `json:"payment_status"`
	PaymentMethod  PaymentMethod     `json:"payment_method"`
	CreatedAt      time.Time         `json:"created_at"`
}

// Wallet represents a user's prepaid wallet
type Wallet struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id"`
	Balance   float64   `json:"balance"`
	Currency  string    `json:"currency"`
	IsLocked  bool      `json:"is_locked"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// WalletTransaction records all movements in and out of a wallet
type WalletTransaction struct {
	ID          string    `json:"id"`
	WalletID    string    `json:"wallet_id"`
	UserID      string    `json:"user_id"`
	Amount      float64   `json:"amount"`
	Type        string    `json:"type"` // TOPUP, DEBIT_RIDE, EARNING_DRIVER, COMMISSION, PAYOUT, REFUND
	ReferenceID string    `json:"reference_id,omitempty"`
	Notes       string    `json:"notes,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// PayoutRequest represents a driver request to withdraw money
type PayoutRequest struct {
	DriverID      string  `json:"driver_id"`
	Amount        float64 `json:"amount"`
	BankCode      string  `json:"bank_code"`
	AccountNumber string  `json:"account_number"`
	AccountHolder string  `json:"account_holder"`
}

// EInvoiceRequest for Thông tư 78 / NĐ 123 e-invoicing
type EInvoiceRequest struct {
	OrderID    string  `json:"order_id"`
	BuyerName  string  `json:"buyer_name"`
	BuyerTaxID string  `json:"buyer_tax_id,omitempty"`
	BuyerEmail string  `json:"buyer_email,omitempty"`
	Amount     float64 `json:"amount"`
}
