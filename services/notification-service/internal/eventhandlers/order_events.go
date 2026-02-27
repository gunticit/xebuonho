package eventhandlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/xebuonho/pkg/kafka"
)

// NotificationEventHandler handles events and triggers push/SMS notifications
type NotificationEventHandler struct {
	logger *log.Logger
}

// NewNotificationEventHandler creates a new notification event handler
func NewNotificationEventHandler() *NotificationEventHandler {
	return &NotificationEventHandler{
		logger: log.New(log.Writer(), "[notification] ", log.LstdFlags),
	}
}

// HandleOrderCreated sends push notification to customer
func (h *NotificationEventHandler) HandleOrderCreated(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.OrderEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal order data: %w", err)
	}

	h.logger.Printf("📦 Order %s created [%s] - Pushing notification to customer %s",
		data.OrderID, data.ServiceType, data.CustomerID)

	// In production: send Firebase Cloud Messaging push notification
	// fcm.Send(ctx, data.CustomerID, "Đơn hàng đã tạo", fmt.Sprintf("Đơn %s đang tìm tài xế...", data.OrderID))

	return nil
}

// HandleOrderStatusChanged routes notifications based on status
func (h *NotificationEventHandler) HandleOrderStatusChanged(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.OrderEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	switch data.Status {
	case "driver_assigned":
		h.logger.Printf("🚗 Driver %s assigned to order %s - Notifying customer %s",
			data.DriverID, data.OrderID, data.CustomerID)
		// Push to customer: "Tài xế đang đến..."

	case "driver_arrived":
		h.logger.Printf("📍 Driver arrived for order %s - Notifying customer %s",
			data.OrderID, data.CustomerID)
		// Push to customer: "Tài xế đã đến điểm đón!"

	case "in_progress":
		h.logger.Printf("🏃 Order %s in progress", data.OrderID)
		// Push: "Đang trên đường..."

	case "food_ready":
		h.logger.Printf("🍜 Food ready for order %s - Notifying driver %s",
			data.OrderID, data.DriverID)
		// Push to driver: "Đồ ăn đã sẵn sàng, hãy đến lấy!"

	case "completed":
		h.logger.Printf("✅ Order %s completed - Notifying customer %s",
			data.OrderID, data.CustomerID)
		// Push customer: "Chuyến đi hoàn tất! Hãy đánh giá tài xế."

	default:
		h.logger.Printf("📋 Status changed: %s -> %s for order %s",
			data.PreviousStatus, data.Status, data.OrderID)
	}

	return nil
}

// HandleOrderCancelled notifies both parties
func (h *NotificationEventHandler) HandleOrderCancelled(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.OrderEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("❌ Order %s cancelled by %s: %s",
		data.OrderID, data.CancelledBy, data.CancelReason)

	if data.CancelledBy == "customer" && data.DriverID != "" {
		// Push to driver: "Khách hàng đã hủy chuyến"
		h.logger.Printf("  → Notifying driver %s about cancellation", data.DriverID)
	} else if data.CancelledBy == "driver" {
		// Push to customer: "Tài xế đã hủy, đang tìm tài xế mới..."
		h.logger.Printf("  → Notifying customer %s about cancellation", data.CustomerID)
	}

	return nil
}

// RegisterHandlers sets up all event handlers on a consumer
func RegisterNotificationHandlers(consumer *kafka.Consumer) {
	handler := NewNotificationEventHandler()
	consumer.On(kafka.EventOrderCreated, handler.HandleOrderCreated)
	consumer.On(kafka.EventOrderStatusChanged, handler.HandleOrderStatusChanged)
	consumer.On(kafka.EventOrderCancelled, handler.HandleOrderCancelled)
}
