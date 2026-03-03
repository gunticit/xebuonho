package kafka

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// ==========================================
// Event Types (CloudEvents spec)
// ==========================================

// CloudEvent represents a CloudEvents v1.0 formatted event
type CloudEvent struct {
	SpecVersion     string          `json:"specversion"`
	Type            string          `json:"type"`
	Source          string          `json:"source"`
	ID              string          `json:"id"`
	Time            string          `json:"time"`
	DataContentType string          `json:"datacontenttype"`
	Data            json.RawMessage `json:"data"`
}

// NewCloudEvent creates a new CloudEvent
func NewCloudEvent(eventType, source string, data interface{}) (*CloudEvent, error) {
	dataBytes, err := json.Marshal(data)
	if err != nil {
		return nil, fmt.Errorf("marshal event data: %w", err)
	}

	return &CloudEvent{
		SpecVersion:     "1.0",
		Type:            eventType,
		Source:          source,
		ID:              "evt-" + uuid.New().String(),
		Time:            time.Now().UTC().Format(time.RFC3339),
		DataContentType: "application/json",
		Data:            dataBytes,
	}, nil
}

// ==========================================
// Topic Names
// ==========================================
const (
	TopicOrderEvents      = "order.events"
	TopicRideEvents       = "ride.events"
	TopicMerchantEvents   = "merchant.events"
	TopicDriverEvents     = "driver.events"
	TopicPaymentEvents    = "payment.events"
	TopicNotificationCmds = "notification.commands"
	TopicAnalyticsEvents  = "analytics.events"
)

// ==========================================
// Order Events
// ==========================================
const (
	EventOrderCreated        = "order.created"
	EventOrderDriverAssigned = "order.driver_assigned"
	EventOrderPickedUp       = "order.picked_up"
	EventOrderDelivered      = "order.delivered"
	EventOrderCompleted      = "order.completed"
	EventOrderCancelled      = "order.cancelled"
	EventOrderStatusChanged  = "order.status_changed"
)

// OrderEventData is the data payload for order events
type OrderEventData struct {
	OrderID        string  `json:"order_id"`
	ServiceType    string  `json:"service_type"`
	CustomerID     string  `json:"customer_id"`
	DriverID       string  `json:"driver_id,omitempty"`
	MerchantID     string  `json:"merchant_id,omitempty"`
	Status         string  `json:"status"`
	PreviousStatus string  `json:"previous_status,omitempty"`
	FareEstimate   float64 `json:"fare_estimate,omitempty"`
	FareFinal      float64 `json:"fare_final,omitempty"`
	CancelledBy    string  `json:"cancelled_by,omitempty"`
	CancelReason   string  `json:"cancel_reason,omitempty"`
}

// ==========================================
// Ride Events
// ==========================================
const (
	EventRideCreated        = "ride.created"
	EventRideDriverAssigned = "ride.driver_assigned"
	EventRideDriverArriving = "ride.driver_arriving"
	EventRideArrived        = "ride.arrived"
	EventRideInProgress     = "ride.in_progress"
	EventRideCompleted      = "ride.completed"
	EventRideCancelled      = "ride.cancelled"
)

// RideEventData is the data payload for ride events
type RideEventData struct {
	RideID       string  `json:"ride_id"`
	RiderID      string  `json:"rider_id"`
	DriverID     string  `json:"driver_id,omitempty"`
	PickupLat    float64 `json:"pickup_lat"`
	PickupLng    float64 `json:"pickup_lng"`
	DropoffLat   float64 `json:"dropoff_lat"`
	DropoffLng   float64 `json:"dropoff_lng"`
	VehicleType  string  `json:"vehicle_type"`
	FareEstimate float64 `json:"fare_estimate"`
	Status       string  `json:"status"`
}

// ==========================================
// Merchant Events
// ==========================================
const (
	EventMerchantOrderConfirmed = "merchant.order_confirmed"
	EventMerchantOrderRejected  = "merchant.order_rejected"
	EventMerchantFoodReady      = "merchant.food_ready"
)

// ==========================================
// Driver Events
// ==========================================
const (
	EventDriverLocationUpdated = "driver.location_updated"
	EventDriverWentOnline      = "driver.went_online"
	EventDriverWentOffline     = "driver.went_offline"
	EventDriverSOSActivated    = "driver.sos_activated"
	EventDriverSOSDeactivated  = "driver.sos_deactivated"
	EventDriverTripStarted     = "driver.trip_started"
	EventDriverTripCompleted   = "driver.trip_completed"
)

// DriverEventData is the data payload for driver events
type DriverEventData struct {
	DriverID    string  `json:"driver_id"`
	DriverName  string  `json:"driver_name,omitempty"`
	Lat         float64 `json:"lat"`
	Lng         float64 `json:"lng"`
	Speed       float64 `json:"speed,omitempty"`
	Heading     float64 `json:"heading,omitempty"`
	Battery     float64 `json:"battery,omitempty"`
	Status      string  `json:"status"`
	VehicleType string  `json:"vehicle_type,omitempty"`
	RideID      string  `json:"ride_id,omitempty"`
	SOSReason   string  `json:"sos_reason,omitempty"`
}

// ==========================================
// Notification Commands
// ==========================================
const (
	CmdSendPush  = "notification.push"
	CmdSendSMS   = "notification.sms"
	CmdSendEmail = "notification.email"
)

// NotificationCommand is the payload for notification commands
type NotificationCommand struct {
	UserID  string            `json:"user_id"`
	Channel string            `json:"channel"` // push, sms, email
	Title   string            `json:"title"`
	Body    string            `json:"body"`
	Data    map[string]string `json:"data,omitempty"`
}
