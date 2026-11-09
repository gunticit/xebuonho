package service

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/xebuonho/services/payment-service/internal/model"
	"github.com/xebuonho/services/payment-service/internal/repository"
)

type PaymentService interface {
	ProcessPayment(ctx context.Context, req model.PaymentRequest) (*model.PaymentResponse, error)
	CreateFinalInvoice(ctx context.Context, orderID string, actualDistance float64, actualDuration int) (*model.Invoice, error)
	HandleSePayWebhook(ctx context.Context, payload model.SePayWebhookPayload) error

	// Wallet Operations
	GetWallet(ctx context.Context, userID string) (*model.Wallet, error)
	TopUpWallet(ctx context.Context, userID string, amount float64, paymentMethod string) (*model.Wallet, *model.PaymentResponse, error)
	DeductDriverCommission(ctx context.Context, driverID, orderID string, totalFare, commissionRate float64) (*model.Wallet, error)
	RequestPayout(ctx context.Context, req model.PayoutRequest) (*model.Wallet, error)
	GetWalletTransactions(ctx context.Context, userID string, limit, offset int) ([]model.WalletTransaction, error)

	// E-Invoice (TT 78/2021/TT-BTC)
	GenerateEInvoice(ctx context.Context, req model.EInvoiceRequest) (*model.Invoice, error)
}

type paymentService struct {
	repo repository.PaymentRepository
}

func NewPaymentService(repo repository.PaymentRepository) PaymentService {
	return &paymentService{repo: repo}
}

func (s *paymentService) CreateFinalInvoice(ctx context.Context, orderID string, actualDistance float64, actualDuration int) (*model.Invoice, error) {
	log.Printf("[payment-service] Calculating final invoice for order %s", orderID)

	// In real app, we fetch the original fare estimate from Ride Service
	// For now, we simulate final calculation
	total := 15000.0 + (actualDistance * 5000.0) + (float64(actualDuration) * 300.0)

	invoice := &model.Invoice{
		OrderID:       orderID,
		TotalAmount:   total,
		PaymentStatus: model.TxStatusPending,
		PaymentMethod: model.PaymentMethodCash,
		CreatedAt:     time.Now(),
	}

	if err := s.repo.SaveInvoice(ctx, invoice); err != nil {
		return nil, fmt.Errorf("save invoice: %w", err)
	}

	return invoice, nil
}

func (s *paymentService) ProcessPayment(ctx context.Context, req model.PaymentRequest) (*model.PaymentResponse, error) {
	log.Printf("[payment-service] Processing payment for order %s: %.2f VND", req.OrderID, req.Amount)

	if req.PaymentMethod == model.PaymentMethodQR {
		// Generate VietQR using SePay format
		// format: https://img.vietqr.io/image/<BANK_ID>-<ACCOUNT_NO>-<TEMPLATE>.png?amount=<AMOUNT>&addInfo=<INFO>
		bankID := "MBBANK" // Example bank
		accountNo := "123456789"
		transferNote := fmt.Sprintf("XBN%s", req.OrderID)
		qrUrl := fmt.Sprintf("https://img.vietqr.io/image/%s-%s-compact.png?amount=%.0f&addInfo=%s",
			bankID, accountNo, req.Amount, transferNote)

		return &model.PaymentResponse{
			TransactionID: uuid.New().String(),
			Status:        model.TxStatusPending,
			PaidAmount:    req.Amount,
			QRUrl:         qrUrl,
			TransferNote:  transferNote,
		}, nil
	}

	// Simulate other payment methods
	txID := uuid.New().String()
	resp := &model.PaymentResponse{
		TransactionID: txID,
		Status:        model.TxStatusCompleted,
		PaidAmount:    req.Amount,
		PaidAt:        time.Now(),
	}

	if err := s.repo.CreateTransaction(ctx, resp); err != nil {
		return nil, fmt.Errorf("create transaction: %w", err)
	}

	return resp, nil
}

func (s *paymentService) HandleSePayWebhook(ctx context.Context, payload model.SePayWebhookPayload) error {
	log.Printf("[payment-service] Received SePay Webhook: Content=%s, Amount=%.2f", payload.Content, payload.Amount)

	// 1. Extract OrderID from content (Format: XBN[OrderID])
	if len(payload.Content) < 4 || payload.Content[:3] != "XBN" {
		return fmt.Errorf("invalid transfer note format")
	}
	orderID := payload.Content[3:]

	// 2. Update transaction status to completed
	// In a real app, we verify the amount matches the invoice first
	txID := uuid.New().String() // In reality, we'd look up the existing pending tx for this order
	resp := &model.PaymentResponse{
		TransactionID: txID,
		Status:        model.TxStatusCompleted,
		PaidAmount:    payload.Amount,
		PaidAt:        payload.CreatedAt,
	}

	if err := s.repo.CreateTransaction(ctx, resp); err != nil {
		return fmt.Errorf("complete transaction from webhook: %w", err)
	}

	log.Printf("[payment-service] Order %s marked as paid via SePay", orderID)
	return nil
}

func (s *paymentService) GetWallet(ctx context.Context, userID string) (*model.Wallet, error) {
	return s.repo.GetWalletByUserID(ctx, userID)
}

func (s *paymentService) TopUpWallet(ctx context.Context, userID string, amount float64, paymentMethod string) (*model.Wallet, *model.PaymentResponse, error) {
	if amount <= 0 {
		return nil, nil, fmt.Errorf("amount must be greater than zero")
	}

	txID := uuid.New().String()
	transferNote := fmt.Sprintf("TOPUP%s", txID[:8])

	// For QR topup, generate VietQR
	var qrUrl string
	if paymentMethod == "qr" || paymentMethod == "sepay" {
		bankID := "MBBANK"
		accountNo := "123456789"
		qrUrl = fmt.Sprintf("https://img.vietqr.io/image/%s-%s-compact.png?amount=%.0f&addInfo=%s",
			bankID, accountNo, amount, transferNote)
	}

	// Credit wallet immediately for card/demo, or credit upon webhook
	w, err := s.repo.CreditWallet(ctx, userID, amount, "TOPUP", txID, fmt.Sprintf("Nạp tiền vào ví qua %s", paymentMethod))
	if err != nil {
		return nil, nil, fmt.Errorf("credit wallet: %w", err)
	}

	resp := &model.PaymentResponse{
		TransactionID: txID,
		Status:        model.TxStatusCompleted,
		PaidAmount:    amount,
		PaidAt:        time.Now(),
		QRUrl:         qrUrl,
		TransferNote:  transferNote,
	}

	return w, resp, nil
}

func (s *paymentService) DeductDriverCommission(ctx context.Context, driverID, orderID string, totalFare, commissionRate float64) (*model.Wallet, error) {
	if commissionRate <= 0 {
		commissionRate = 0.15 // Default 15% platform commission
	}
	commissionAmt := totalFare * commissionRate

	notes := fmt.Sprintf("Khấu trừ hoa hồng %.0f%% cho chuyến xe %s", commissionRate*100, orderID)
	w, err := s.repo.AtomicDeductWallet(ctx, driverID, commissionAmt, "COMMISSION", orderID, notes)
	if err != nil {
		return nil, fmt.Errorf("deduct commission: %w (driver wallet balance might be insufficient)", err)
	}

	log.Printf("[payment-service] Deducted %.2f VND commission from driver %s for order %s. Remaining: %.2f",
		commissionAmt, driverID, orderID, w.Balance)
	return w, nil
}

func (s *paymentService) RequestPayout(ctx context.Context, req model.PayoutRequest) (*model.Wallet, error) {
	if req.Amount < 50000 {
		return nil, fmt.Errorf("minimum payout amount is 50,000 VND")
	}

	notes := fmt.Sprintf("Rút tiền về tài khoản %s - %s (%s)", req.BankCode, req.AccountNumber, req.AccountHolder)
	payoutID := uuid.New().String()

	// Atomically deduct wallet balance
	w, err := s.repo.AtomicDeductWallet(ctx, req.DriverID, req.Amount, "PAYOUT", payoutID, notes)
	if err != nil {
		return nil, fmt.Errorf("insufficient balance for payout: %w", err)
	}

	log.Printf("[payment-service] Driver %s payout of %.2f VND processed (ID: %s)", req.DriverID, req.Amount, payoutID)
	return w, nil
}

func (s *paymentService) GetWalletTransactions(ctx context.Context, userID string, limit, offset int) ([]model.WalletTransaction, error) {
	return s.repo.GetWalletTransactions(ctx, userID, limit, offset)
}

func (s *paymentService) GenerateEInvoice(ctx context.Context, req model.EInvoiceRequest) (*model.Invoice, error) {
	vatAmt := req.Amount * 0.08 // 8% VAT for transport services in Vietnam
	invoiceNum := fmt.Sprintf("INV-2026-%s", uuid.New().String()[:8])

	inv := &model.Invoice{
		OrderID:       req.OrderID,
		InvoiceNumber: invoiceNum,
		BuyerName:     req.BuyerName,
		TaxCode:       req.BuyerTaxID,
		TotalAmount:   req.Amount,
		VATAmt:        vatAmt,
		PaymentStatus: model.TxStatusCompleted,
		PaymentMethod: model.PaymentMethodWallet,
		CreatedAt:     time.Now(),
	}

	if err := s.repo.SaveInvoice(ctx, inv); err != nil {
		return nil, fmt.Errorf("save e-invoice: %w", err)
	}

	log.Printf("[payment-service] e-Invoice %s generated for order %s (Amount: %.2f VND, VAT: %.2f)",
		invoiceNum, req.OrderID, req.Amount, vatAmt)
	return inv, nil
}
