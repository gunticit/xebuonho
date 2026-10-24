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
