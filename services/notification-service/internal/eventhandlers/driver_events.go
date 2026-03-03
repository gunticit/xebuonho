package eventhandlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/xebuonho/pkg/kafka"
)

// DriverEventHandler handles driver events (SOS, status changes)
type DriverEventHandler struct {
	logger *log.Logger
}

// NewDriverEventHandler creates a new driver event handler
func NewDriverEventHandler() *DriverEventHandler {
	return &DriverEventHandler{
		logger: log.New(log.Writer(), "[notification-driver] ", log.LstdFlags),
	}
}

// HandleDriverSOSActivated triggers emergency notifications
func (h *DriverEventHandler) HandleDriverSOSActivated(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.DriverEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal driver data: %w", err)
	}

	h.logger.Printf("🚨 SOS ACTIVATED by driver %s (%s) at [%.4f, %.4f]",
		data.DriverID, data.DriverName, data.Lat, data.Lng)

	// In production:
	// 1. Send SMS to emergency contacts
	// 2. Alert ops center via push
	// 3. Send location to authorities if configured
	// sms.Send(ctx, emergencyContacts, "SOS từ tài xế " + data.DriverName, ...)

	return nil
}

// HandleDriverSOSDeactivated logs SOS cancellation
func (h *DriverEventHandler) HandleDriverSOSDeactivated(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.DriverEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("✅ SOS deactivated by driver %s", data.DriverID)
	return nil
}

// HandleDriverWentOnline logs driver coming online
func (h *DriverEventHandler) HandleDriverWentOnline(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.DriverEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("🟢 Driver %s went online [%s] at [%.4f, %.4f]",
		data.DriverID, data.VehicleType, data.Lat, data.Lng)
	return nil
}

// HandleDriverWentOffline logs driver going offline
func (h *DriverEventHandler) HandleDriverWentOffline(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.DriverEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("🔴 Driver %s went offline", data.DriverID)
	return nil
}

// RegisterDriverHandlers sets up all driver event handlers on a consumer
func RegisterDriverHandlers(consumer *kafka.Consumer) {
	handler := NewDriverEventHandler()
	consumer.On(kafka.EventDriverSOSActivated, handler.HandleDriverSOSActivated)
	consumer.On(kafka.EventDriverSOSDeactivated, handler.HandleDriverSOSDeactivated)
	consumer.On(kafka.EventDriverWentOnline, handler.HandleDriverWentOnline)
	consumer.On(kafka.EventDriverWentOffline, handler.HandleDriverWentOffline)
}
