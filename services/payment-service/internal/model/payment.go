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
	OrderID        string    `json:"order_id"`
	BaseFare       float64   `json:"base_fare"`
	DistanceFare   float64   `json:"distance_fare"`
	TimeFare       float64   `json:"time_fare"`
	SurgeAmount    float64   `json:"surge_amount"`
	PlatformFee    float64   `json:"platform_fee"`
	Discount       float64   `json:"discount"`
	TotalAmount    float64   `json:"total_amount"`
	PaymentStatus  TransactionStatus `json:"payment_status"`
	PaymentMethod  PaymentMethod    `json:"payment_method"`
	CreatedAt      time.Time `json:"created_at"`
}
