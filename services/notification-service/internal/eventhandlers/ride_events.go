package eventhandlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/xebuonho/pkg/kafka"
)

// RideEventHandler handles ride events and triggers push/SMS notifications
type RideEventHandler struct {
	logger *log.Logger
}

// NewRideEventHandler creates a new ride event handler
func NewRideEventHandler() *RideEventHandler {
	return &RideEventHandler{
		logger: log.New(log.Writer(), "[notification-ride] ", log.LstdFlags),
	}
}

// HandleRideCreated notifies rider that search for driver has started
func (h *RideEventHandler) HandleRideCreated(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.RideEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal ride data: %w", err)
	}

	h.logger.Printf("🚗 Ride %s created [%s] - Notifying rider %s: Đang tìm tài xế...",
		data.RideID, data.VehicleType, data.RiderID)

	// In production: send push notification via FCM
	// fcm.Send(ctx, data.RiderID, "Đang tìm tài xế", "Chúng tôi đang tìm tài xế gần bạn...")

	return nil
}

// HandleRideDriverAssigned notifies rider that driver accepted
func (h *RideEventHandler) HandleRideDriverAssigned(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.RideEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("✅ Driver %s assigned to ride %s - Notifying rider %s",
		data.DriverID, data.RideID, data.RiderID)

	// Push to rider: "Tài xế đang đến đón bạn!"
	return nil
}

// HandleRideDriverArriving notifies rider that driver is on the way
func (h *RideEventHandler) HandleRideDriverArriving(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.RideEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("🚗 Driver arriving for ride %s - Notifying rider %s",
		data.RideID, data.RiderID)

	// Push to rider: "Tài xế đang trên đường đến..."
	return nil
}

// HandleRideArrived notifies rider that driver has arrived
func (h *RideEventHandler) HandleRideArrived(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.RideEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("📍 Driver arrived for ride %s - Notifying rider %s",
		data.RideID, data.RiderID)

	// Push to rider: "Tài xế đã đến! Hãy ra xe."
	return nil
}

// HandleRideCompleted notifies rider to rate driver
func (h *RideEventHandler) HandleRideCompleted(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.RideEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("✅ Ride %s completed - Notifying rider %s to rate driver",
		data.RideID, data.RiderID)

	// Push to rider: "Chuyến đi hoàn thành! Hãy đánh giá tài xế."
	return nil
}

// HandleRideCancelled notifies both parties about cancellation
func (h *RideEventHandler) HandleRideCancelled(ctx context.Context, event kafka.CloudEvent) error {
	var data kafka.RideEventData
	if err := json.Unmarshal(event.Data, &data); err != nil {
		return fmt.Errorf("unmarshal: %w", err)
	}

	h.logger.Printf("❌ Ride %s cancelled - Notifying rider %s and driver %s",
		data.RideID, data.RiderID, data.DriverID)

	// Push to rider if driver cancelled: "Tài xế đã hủy, đang tìm tài xế mới..."
	// Push to driver if rider cancelled: "Khách hàng đã hủy chuyến."
	return nil
}

// RegisterRideHandlers sets up all ride event handlers on a consumer
func RegisterRideHandlers(consumer *kafka.Consumer) {
	handler := NewRideEventHandler()
	consumer.On(kafka.EventRideCreated, handler.HandleRideCreated)
	consumer.On(kafka.EventRideDriverAssigned, handler.HandleRideDriverAssigned)
	consumer.On(kafka.EventRideDriverArriving, handler.HandleRideDriverArriving)
	consumer.On(kafka.EventRideArrived, handler.HandleRideArrived)
	consumer.On(kafka.EventRideCompleted, handler.HandleRideCompleted)
	consumer.On(kafka.EventRideCancelled, handler.HandleRideCancelled)
}
