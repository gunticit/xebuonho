// Package statemachine implements finite state machines for managing
// order lifecycle transitions across all 4 service types:
// Ride, Food Delivery, Grocery Shopping, Designated Driver.
//
// Usage:
//
//	sm := statemachine.NewStateMachine(statemachine.ServiceTypeRide)
//	err := sm.ProcessEvent(order, statemachine.EventDriverAccepted)
package statemachine

import (
	"fmt"
	"time"
)

// ServiceType represents the type of service
type ServiceType string

const (
	ServiceTypeRide             ServiceType = "ride"
	ServiceTypeFoodDelivery     ServiceType = "food_delivery"
	ServiceTypeGrocery          ServiceType = "grocery"
	ServiceTypeDesignatedDriver ServiceType = "designated_driver"
)

// OrderStatus represents the current state of an order
type OrderStatus string

// ==========================================
// Shared statuses (all service types)
// ==========================================
const (
	StatusCreated           OrderStatus = "created"
	StatusSearchingDriver   OrderStatus = "searching_driver"
	StatusNoDriver          OrderStatus = "no_driver"
	StatusDriverAssigned    OrderStatus = "driver_assigned"
	StatusCancelledCustomer OrderStatus = "cancelled_by_customer"
	StatusCancelledDriver   OrderStatus = "cancelled_by_driver"
	StatusCompleted         OrderStatus = "completed"
	StatusPaymentPending    OrderStatus = "payment_pending"
	StatusPaid              OrderStatus = "paid"
)

// ==========================================
// Ride-specific statuses
// ==========================================
const (
	StatusDriverArriving   OrderStatus = "driver_arriving"
	StatusArrived          OrderStatus = "arrived"
	StatusWaitingPassenger OrderStatus = "waiting_passenger"
	StatusInProgress       OrderStatus = "in_progress"
)

// ==========================================
// Food Delivery-specific statuses
// ==========================================
const (
	StatusPlaced            OrderStatus = "placed"
	StatusMerchantConfirmed OrderStatus = "merchant_confirmed"
	StatusMerchantRejected  OrderStatus = "merchant_rejected"
	StatusPreparing         OrderStatus = "preparing"
	StatusReadyForPickup    OrderStatus = "ready_for_pickup"
	StatusDriverToMerchant  OrderStatus = "driver_to_merchant"
	StatusAtMerchant        OrderStatus = "at_merchant"
	StatusPickedUp          OrderStatus = "picked_up"
	StatusDelivering        OrderStatus = "delivering"
	StatusDelivered         OrderStatus = "delivered"
)

// ==========================================
// Grocery-specific statuses
// ==========================================
const (
	StatusDriverToStore    OrderStatus = "driver_to_store"
	StatusAtStore          OrderStatus = "at_store"
	StatusShopping         OrderStatus = "shopping"
	StatusItemSubstitution OrderStatus = "item_substitution"
	StatusShoppingDone     OrderStatus = "shopping_done"
	StatusReceiptUploaded  OrderStatus = "receipt_uploaded"
	// StatusDelivering and StatusDelivered reused from food
)

// ==========================================
// Designated Driver-specific statuses
// ==========================================
const (
	// StatusDriverArriving reused from ride
	// StatusArrived reused from ride
	StatusVehicleInspection  OrderStatus = "vehicle_inspection"
	StatusDriving            OrderStatus = "driving"
	StatusArrivedDestination OrderStatus = "arrived_destination"
	StatusVehicleHandover    OrderStatus = "vehicle_handover"
)

// OrderEvent represents an event that triggers a state transition
type OrderEvent string

const (
	// Shared events
	EventDriverFound       OrderEvent = "driver_found"
	EventNoDriverAvailable OrderEvent = "no_driver_available"
	EventDriverAccepted    OrderEvent = "driver_accepted"
	EventDriverRejected    OrderEvent = "driver_rejected"
	EventCustomerCancelled OrderEvent = "customer_cancelled"
	EventDriverCancelled   OrderEvent = "driver_cancelled"
	EventPaymentSuccess    OrderEvent = "payment_success"
	EventPaymentFailed     OrderEvent = "payment_failed"
	EventTimeout           OrderEvent = "timeout"
	EventRetry             OrderEvent = "retry"

	// Ride events
	EventDriverArrived     OrderEvent = "driver_arrived"
	EventPassengerPickedUp OrderEvent = "passenger_picked_up"
	EventTripCompleted     OrderEvent = "trip_completed"

	// Food events
	EventMerchantConfirmed OrderEvent = "merchant_confirmed"
	EventMerchantRejected  OrderEvent = "merchant_rejected"
	EventStartPreparing    OrderEvent = "start_preparing"
	EventFoodReady         OrderEvent = "food_ready"
	EventArrivedMerchant   OrderEvent = "arrived_merchant"
	EventFoodPickedUp      OrderEvent = "food_picked_up"
	EventDelivered         OrderEvent = "delivered"

	// Grocery events
	EventArrivedStore     OrderEvent = "arrived_store"
	EventStartShopping    OrderEvent = "start_shopping"
	EventItemSubstitution OrderEvent = "item_substitution"
	EventSubstitutionDone OrderEvent = "substitution_done"
	EventShoppingDone     OrderEvent = "shopping_done"
	EventReceiptUploaded  OrderEvent = "receipt_uploaded"

	// Designated driver events
	EventVehicleInspected  OrderEvent = "vehicle_inspected"
	EventStartDriving      OrderEvent = "start_driving"
	EventArrivedDest       OrderEvent = "arrived_destination"
	EventVehicleHandedOver OrderEvent = "vehicle_handed_over"
)

// StatusEntry records a state transition for audit
type StatusEntry struct {
	From      OrderStatus
	To        OrderStatus
	Event     OrderEvent
	Actor     string // who triggered the event
	Timestamp time.Time
}

// Order is the minimal interface needed for state machine processing
type Order struct {
	ID            string
	ServiceType   ServiceType
	Status        OrderStatus
	DriverID      *string
	MerchantID    *string
	AcceptedAt    *time.Time
	PickedUpAt    *time.Time
	DeliveredAt   *time.Time
	CompletedAt   *time.Time
	CancelledAt   *time.Time
	CancelledBy   string
	UpdatedAt     time.Time
	StatusHistory []StatusEntry
}

// Transition defines a valid state transition
type Transition struct {
	From   OrderStatus
	Event  OrderEvent
	To     OrderStatus
	Guard  func(order *Order) error
	Action func(order *Order) error
}

// StateMachine manages order state transitions
type StateMachine struct {
	serviceType ServiceType
	transitions []Transition
}

// NewStateMachine creates a state machine for the specified service type
func NewStateMachine(serviceType ServiceType) *StateMachine {
	var transitions []Transition
	switch serviceType {
	case ServiceTypeRide:
		transitions = rideTransitions()
	case ServiceTypeFoodDelivery:
		transitions = foodDeliveryTransitions()
	case ServiceTypeGrocery:
		transitions = groceryTransitions()
	case ServiceTypeDesignatedDriver:
		transitions = designatedDriverTransitions()
	default:
		transitions = rideTransitions()
	}
	return &StateMachine{serviceType: serviceType, transitions: transitions}
}

// ProcessEvent validates and executes a state transition
func (sm *StateMachine) ProcessEvent(order *Order, event OrderEvent) error {
	for _, t := range sm.transitions {
		if t.From == order.Status && t.Event == event {
			if t.Guard != nil {
				if err := t.Guard(order); err != nil {
					return fmt.Errorf("guard failed [%s --%s--> %s]: %w",
						t.From, event, t.To, err)
				}
			}

			oldStatus := order.Status
			order.Status = t.To
			order.UpdatedAt = time.Now()

			if t.Action != nil {
				if err := t.Action(order); err != nil {
					order.Status = oldStatus
					return fmt.Errorf("action failed [%s --%s--> %s]: %w",
						oldStatus, event, t.To, err)
				}
			}

			order.StatusHistory = append(order.StatusHistory, StatusEntry{
				From:      oldStatus,
				To:        t.To,
				Event:     event,
				Timestamp: time.Now(),
			})

			return nil
		}
	}

	return fmt.Errorf("invalid transition for %s: %s + %s", sm.serviceType, order.Status, event)
}

// CanTransition checks if a transition is valid without executing it
func (sm *StateMachine) CanTransition(status OrderStatus, event OrderEvent) bool {
	for _, t := range sm.transitions {
		if t.From == status && t.Event == event {
			return true
		}
	}
	return false
}

// GetValidEvents returns all valid events for the current status
func (sm *StateMachine) GetValidEvents(status OrderStatus) []OrderEvent {
	events := make([]OrderEvent, 0)
	for _, t := range sm.transitions {
		if t.From == status {
			events = append(events, t.Event)
		}
	}
	return events
}

// helper
func nowPtr() *time.Time { t := time.Now(); return &t }

// ==========================================
// 🚗 Ride Transitions
// ==========================================
func rideTransitions() []Transition {
	return []Transition{
		{From: StatusCreated, Event: EventDriverFound, To: StatusDriverAssigned},
		{From: StatusCreated, Event: EventNoDriverAvailable, To: StatusNoDriver},
		{From: StatusCreated, Event: EventCustomerCancelled, To: StatusCancelledCustomer},
		{From: StatusNoDriver, Event: EventRetry, To: StatusCreated},
		{From: StatusDriverAssigned, Event: EventDriverAccepted, To: StatusDriverArriving,
			Action: func(o *Order) error { o.AcceptedAt = nowPtr(); return nil }},
		{From: StatusDriverAssigned, Event: EventDriverRejected, To: StatusCreated,
			Action: func(o *Order) error { o.DriverID = nil; return nil }},
		{From: StatusDriverAssigned, Event: EventCustomerCancelled, To: StatusCancelledCustomer},
		{From: StatusDriverArriving, Event: EventDriverArrived, To: StatusArrived},
		{From: StatusDriverArriving, Event: EventCustomerCancelled, To: StatusCancelledCustomer},
		{From: StatusDriverArriving, Event: EventDriverCancelled, To: StatusCancelledDriver},
		{From: StatusArrived, Event: EventPassengerPickedUp, To: StatusInProgress,
			Action: func(o *Order) error { o.PickedUpAt = nowPtr(); return nil }},
		{From: StatusArrived, Event: EventDriverCancelled, To: StatusCancelledDriver},
		{From: StatusInProgress, Event: EventTripCompleted, To: StatusCompleted,
			Action: func(o *Order) error { o.CompletedAt = nowPtr(); return nil }},
		{From: StatusCompleted, Event: EventPaymentSuccess, To: StatusPaid},
		{From: StatusCompleted, Event: EventPaymentFailed, To: StatusPaymentPending},
		{From: StatusPaymentPending, Event: EventPaymentSuccess, To: StatusPaid},
	}
}

// ==========================================
// 🍔 Food Delivery Transitions
// ==========================================
func foodDeliveryTransitions() []Transition {
	return []Transition{
		// Order placed → Merchant decision
		{From: StatusPlaced, Event: EventMerchantConfirmed, To: StatusMerchantConfirmed},
		{From: StatusPlaced, Event: EventMerchantRejected, To: StatusMerchantRejected},
		{From: StatusPlaced, Event: EventCustomerCancelled, To: StatusCancelledCustomer},

		// Merchant confirmed → Start preparing (food prep begins)
		{From: StatusMerchantConfirmed, Event: EventStartPreparing, To: StatusPreparing},
		{From: StatusMerchantConfirmed, Event: EventCustomerCancelled, To: StatusCancelledCustomer},

		// During preparation → search for driver + food prep in parallel
		{From: StatusPreparing, Event: EventFoodReady, To: StatusReadyForPickup},
		{From: StatusPreparing, Event: EventDriverFound, To: StatusDriverAssigned},
		{From: StatusPreparing, Event: EventCustomerCancelled, To: StatusCancelledCustomer},

		// Driver assignment & route to merchant
		{From: StatusDriverAssigned, Event: EventDriverAccepted, To: StatusDriverToMerchant,
			Action: func(o *Order) error { o.AcceptedAt = nowPtr(); return nil }},
		{From: StatusDriverAssigned, Event: EventDriverRejected, To: StatusPreparing,
			Action: func(o *Order) error { o.DriverID = nil; return nil }},
		{From: StatusDriverAssigned, Event: EventNoDriverAvailable, To: StatusPreparing},

		// Driver heading to merchant
		{From: StatusDriverToMerchant, Event: EventArrivedMerchant, To: StatusAtMerchant},
		{From: StatusDriverToMerchant, Event: EventDriverCancelled, To: StatusPreparing,
			Action: func(o *Order) error { o.DriverID = nil; o.AcceptedAt = nil; return nil }},

		// At merchant waiting for food
		{From: StatusAtMerchant, Event: EventFoodReady, To: StatusReadyForPickup},
		{From: StatusAtMerchant, Event: EventFoodPickedUp, To: StatusPickedUp,
			Action: func(o *Order) error { o.PickedUpAt = nowPtr(); return nil }},

		// Food ready for pickup
		{From: StatusReadyForPickup, Event: EventDriverFound, To: StatusDriverAssigned},
		{From: StatusReadyForPickup, Event: EventFoodPickedUp, To: StatusPickedUp,
			Action: func(o *Order) error { o.PickedUpAt = nowPtr(); return nil }},

		// Delivering
		{From: StatusPickedUp, Event: EventDelivered, To: StatusDelivered,
			Action: func(o *Order) error { o.DeliveredAt = nowPtr(); return nil }},

		// Payment
		{From: StatusDelivered, Event: EventPaymentSuccess, To: StatusPaid},
		{From: StatusDelivered, Event: EventPaymentFailed, To: StatusPaymentPending},
		{From: StatusPaymentPending, Event: EventPaymentSuccess, To: StatusPaid},
	}
}

// ==========================================
// 🛒 Grocery Transitions
// ==========================================
func groceryTransitions() []Transition {
	return []Transition{
		// Created → Search driver
		{From: StatusCreated, Event: EventDriverFound, To: StatusDriverAssigned},
		{From: StatusCreated, Event: EventNoDriverAvailable, To: StatusNoDriver},
		{From: StatusCreated, Event: EventCustomerCancelled, To: StatusCancelledCustomer},
		{From: StatusNoDriver, Event: EventRetry, To: StatusCreated},

		// Driver assigned → To store
		{From: StatusDriverAssigned, Event: EventDriverAccepted, To: StatusDriverToStore,
			Action: func(o *Order) error { o.AcceptedAt = nowPtr(); return nil }},
		{From: StatusDriverAssigned, Event: EventDriverRejected, To: StatusCreated,
			Action: func(o *Order) error { o.DriverID = nil; return nil }},
		{From: StatusDriverAssigned, Event: EventCustomerCancelled, To: StatusCancelledCustomer},

		// At store → Shopping
		{From: StatusDriverToStore, Event: EventArrivedStore, To: StatusAtStore},
		{From: StatusDriverToStore, Event: EventDriverCancelled, To: StatusCancelledDriver},
		{From: StatusAtStore, Event: EventStartShopping, To: StatusShopping},

		// Shopping (with possible substitutions)
		{From: StatusShopping, Event: EventItemSubstitution, To: StatusItemSubstitution},
		{From: StatusItemSubstitution, Event: EventSubstitutionDone, To: StatusShopping},
		{From: StatusShopping, Event: EventShoppingDone, To: StatusShoppingDone},

		// Receipt → Delivering
		{From: StatusShoppingDone, Event: EventReceiptUploaded, To: StatusReceiptUploaded},
		{From: StatusReceiptUploaded, Event: EventDelivered, To: StatusDelivered,
			Action: func(o *Order) error { o.DeliveredAt = nowPtr(); return nil }},

		// Payment
		{From: StatusDelivered, Event: EventPaymentSuccess, To: StatusPaid},
		{From: StatusDelivered, Event: EventPaymentFailed, To: StatusPaymentPending},
		{From: StatusPaymentPending, Event: EventPaymentSuccess, To: StatusPaid},
	}
}

// ==========================================
// 🚙 Designated Driver Transitions
// ==========================================
func designatedDriverTransitions() []Transition {
	return []Transition{
		// Created → Search driver
		{From: StatusCreated, Event: EventDriverFound, To: StatusDriverAssigned},
		{From: StatusCreated, Event: EventNoDriverAvailable, To: StatusNoDriver},
		{From: StatusCreated, Event: EventCustomerCancelled, To: StatusCancelledCustomer},
		{From: StatusNoDriver, Event: EventRetry, To: StatusCreated},

		// Driver assigned → Arriving
		{From: StatusDriverAssigned, Event: EventDriverAccepted, To: StatusDriverArriving,
			Action: func(o *Order) error { o.AcceptedAt = nowPtr(); return nil }},
		{From: StatusDriverAssigned, Event: EventDriverRejected, To: StatusCreated,
			Action: func(o *Order) error { o.DriverID = nil; return nil }},
		{From: StatusDriverAssigned, Event: EventCustomerCancelled, To: StatusCancelledCustomer},

		// Arriving → Arrived → Inspect vehicle
		{From: StatusDriverArriving, Event: EventDriverArrived, To: StatusArrived},
		{From: StatusDriverArriving, Event: EventCustomerCancelled, To: StatusCancelledCustomer},
		{From: StatusDriverArriving, Event: EventDriverCancelled, To: StatusCancelledDriver},

		// Vehicle inspection (mandatory)
		{From: StatusArrived, Event: EventVehicleInspected, To: StatusVehicleInspection},
		{From: StatusVehicleInspection, Event: EventStartDriving, To: StatusDriving,
			Action: func(o *Order) error { o.PickedUpAt = nowPtr(); return nil }},

		// Driving → Arrival → Handover
		{From: StatusDriving, Event: EventArrivedDest, To: StatusArrivedDestination},
		{From: StatusArrivedDestination, Event: EventVehicleHandedOver, To: StatusCompleted,
			Action: func(o *Order) error { o.CompletedAt = nowPtr(); return nil }},

		// Payment
		{From: StatusCompleted, Event: EventPaymentSuccess, To: StatusPaid},
		{From: StatusCompleted, Event: EventPaymentFailed, To: StatusPaymentPending},
		{From: StatusPaymentPending, Event: EventPaymentSuccess, To: StatusPaid},
	}
}
