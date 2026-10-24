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

	// Simulate payment gateway logic
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
