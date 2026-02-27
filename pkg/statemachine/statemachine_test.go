package statemachine

import (
	"testing"
)

// ==========================================
// Ride State Machine Tests
// ==========================================

func TestRide_HappyPath(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)
	order := &Order{ID: "ride-001", ServiceType: ServiceTypeRide, Status: StatusCreated}

	steps := []struct {
		event    OrderEvent
		expected OrderStatus
	}{
		{EventDriverFound, StatusDriverAssigned},
		{EventDriverAccepted, StatusDriverArriving},
		{EventDriverArrived, StatusArrived},
		{EventPassengerPickedUp, StatusInProgress},
		{EventTripCompleted, StatusCompleted},
		{EventPaymentSuccess, StatusPaid},
	}

	for _, step := range steps {
		if err := sm.ProcessEvent(order, step.event); err != nil {
			t.Fatalf("Event %s failed: %v", step.event, err)
		}
		if order.Status != step.expected {
			t.Fatalf("Expected %s after %s, got %s", step.expected, step.event, order.Status)
		}
	}

	// Verify timestamps were set
	if order.AcceptedAt == nil {
		t.Fatal("AcceptedAt should be set")
	}
	if order.PickedUpAt == nil {
		t.Fatal("PickedUpAt should be set")
	}
	if order.CompletedAt == nil {
		t.Fatal("CompletedAt should be set")
	}
}

func TestRide_CustomerCancelsWhileSearching(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)
	order := &Order{ID: "ride-002", Status: StatusCreated}

	if err := sm.ProcessEvent(order, EventCustomerCancelled); err != nil {
		t.Fatalf("Cancel failed: %v", err)
	}
	if order.Status != StatusCancelledCustomer {
		t.Fatalf("Expected cancelled_by_customer, got %s", order.Status)
	}
}

func TestRide_DriverRejectsReassign(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)
	order := &Order{ID: "ride-003", Status: StatusCreated}
	driverID := "driver-1"
	order.DriverID = &driverID

	sm.ProcessEvent(order, EventDriverFound)
	sm.ProcessEvent(order, EventDriverRejected)

	if order.Status != StatusCreated {
		t.Fatalf("Expected back to created after rejection, got %s", order.Status)
	}
	if order.DriverID != nil {
		t.Fatal("DriverID should be nil after rejection")
	}
}

func TestRide_InvalidTransition(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)
	order := &Order{ID: "ride-004", Status: StatusPaid}

	err := sm.ProcessEvent(order, EventDriverFound)
	if err == nil {
		t.Fatal("Expected error for invalid transition from PAID")
	}
}

func TestRide_NoDriverRetry(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)
	order := &Order{ID: "ride-005", Status: StatusCreated}

	sm.ProcessEvent(order, EventNoDriverAvailable)
	if order.Status != StatusNoDriver {
		t.Fatalf("Expected no_driver, got %s", order.Status)
	}

	sm.ProcessEvent(order, EventRetry)
	if order.Status != StatusCreated {
		t.Fatalf("Expected back to created after retry, got %s", order.Status)
	}
}

// ==========================================
// Food Delivery State Machine Tests
// ==========================================

func TestFoodDelivery_HappyPath(t *testing.T) {
	sm := NewStateMachine(ServiceTypeFoodDelivery)
	order := &Order{ID: "food-001", ServiceType: ServiceTypeFoodDelivery, Status: StatusPlaced}

	steps := []struct {
		event    OrderEvent
		expected OrderStatus
	}{
		{EventMerchantConfirmed, StatusMerchantConfirmed},
		{EventStartPreparing, StatusPreparing},
		{EventDriverFound, StatusDriverAssigned},
		{EventDriverAccepted, StatusDriverToMerchant},
		{EventArrivedMerchant, StatusAtMerchant},
		{EventFoodPickedUp, StatusPickedUp},
		{EventDelivered, StatusDelivered},
		{EventPaymentSuccess, StatusPaid},
	}

	for _, step := range steps {
		if err := sm.ProcessEvent(order, step.event); err != nil {
			t.Fatalf("Event %s failed from %s: %v", step.event, order.Status, err)
		}
		if order.Status != step.expected {
			t.Fatalf("Expected %s after %s, got %s", step.expected, step.event, order.Status)
		}
	}
}

func TestFoodDelivery_MerchantRejects(t *testing.T) {
	sm := NewStateMachine(ServiceTypeFoodDelivery)
	order := &Order{ID: "food-002", Status: StatusPlaced}

	sm.ProcessEvent(order, EventMerchantRejected)
	if order.Status != StatusMerchantRejected {
		t.Fatalf("Expected merchant_rejected, got %s", order.Status)
	}
}

func TestFoodDelivery_DriverCancelsRematches(t *testing.T) {
	sm := NewStateMachine(ServiceTypeFoodDelivery)
	order := &Order{ID: "food-003", Status: StatusPlaced}

	sm.ProcessEvent(order, EventMerchantConfirmed)
	sm.ProcessEvent(order, EventStartPreparing)
	sm.ProcessEvent(order, EventDriverFound)
	sm.ProcessEvent(order, EventDriverAccepted)
	sm.ProcessEvent(order, EventArrivedMerchant)

	// Simulate: food not ready, driver at merchant gets food ready signal
	sm.ProcessEvent(order, EventFoodReady)
	if order.Status != StatusReadyForPickup {
		t.Fatalf("Expected ready_for_pickup, got %s", order.Status)
	}
}

func TestFoodDelivery_DriverRejectsBackToPreparing(t *testing.T) {
	sm := NewStateMachine(ServiceTypeFoodDelivery)
	order := &Order{ID: "food-004", Status: StatusPlaced}
	driverID := "driver-1"

	sm.ProcessEvent(order, EventMerchantConfirmed)
	sm.ProcessEvent(order, EventStartPreparing)
	sm.ProcessEvent(order, EventDriverFound)
	order.DriverID = &driverID
	sm.ProcessEvent(order, EventDriverRejected)

	if order.Status != StatusPreparing {
		t.Fatalf("Expected back to preparing after driver rejects, got %s", order.Status)
	}
	if order.DriverID != nil {
		t.Fatal("DriverID should be cleared after rejection")
	}
}

// ==========================================
// Grocery State Machine Tests
// ==========================================

func TestGrocery_HappyPath(t *testing.T) {
	sm := NewStateMachine(ServiceTypeGrocery)
	order := &Order{ID: "grocery-001", ServiceType: ServiceTypeGrocery, Status: StatusCreated}

	steps := []struct {
		event    OrderEvent
		expected OrderStatus
	}{
		{EventDriverFound, StatusDriverAssigned},
		{EventDriverAccepted, StatusDriverToStore},
		{EventArrivedStore, StatusAtStore},
		{EventStartShopping, StatusShopping},
		{EventItemSubstitution, StatusItemSubstitution},
		{EventSubstitutionDone, StatusShopping},
		{EventShoppingDone, StatusShoppingDone},
		{EventReceiptUploaded, StatusReceiptUploaded},
		{EventDelivered, StatusDelivered},
		{EventPaymentSuccess, StatusPaid},
	}

	for _, step := range steps {
		if err := sm.ProcessEvent(order, step.event); err != nil {
			t.Fatalf("Event %s failed from %s: %v", step.event, order.Status, err)
		}
		if order.Status != step.expected {
			t.Fatalf("Expected %s, got %s", step.expected, order.Status)
		}
	}
}

func TestGrocery_MultipleSubstitutions(t *testing.T) {
	sm := NewStateMachine(ServiceTypeGrocery)
	order := &Order{ID: "grocery-002", Status: StatusCreated}

	sm.ProcessEvent(order, EventDriverFound)
	sm.ProcessEvent(order, EventDriverAccepted)
	sm.ProcessEvent(order, EventArrivedStore)
	sm.ProcessEvent(order, EventStartShopping)

	// Multiple substitution cycles
	for i := 0; i < 3; i++ {
		sm.ProcessEvent(order, EventItemSubstitution)
		if order.Status != StatusItemSubstitution {
			t.Fatalf("Substitution %d: expected item_substitution, got %s", i, order.Status)
		}
		sm.ProcessEvent(order, EventSubstitutionDone)
		if order.Status != StatusShopping {
			t.Fatalf("After sub %d: expected shopping, got %s", i, order.Status)
		}
	}
}

// ==========================================
// Designated Driver State Machine Tests
// ==========================================

func TestDesignatedDriver_HappyPath(t *testing.T) {
	sm := NewStateMachine(ServiceTypeDesignatedDriver)
	order := &Order{ID: "dd-001", ServiceType: ServiceTypeDesignatedDriver, Status: StatusCreated}

	steps := []struct {
		event    OrderEvent
		expected OrderStatus
	}{
		{EventDriverFound, StatusDriverAssigned},
		{EventDriverAccepted, StatusDriverArriving},
		{EventDriverArrived, StatusArrived},
		{EventVehicleInspected, StatusVehicleInspection},
		{EventStartDriving, StatusDriving},
		{EventArrivedDest, StatusArrivedDestination},
		{EventVehicleHandedOver, StatusCompleted},
		{EventPaymentSuccess, StatusPaid},
	}

	for _, step := range steps {
		if err := sm.ProcessEvent(order, step.event); err != nil {
			t.Fatalf("Event %s failed from %s: %v", step.event, order.Status, err)
		}
		if order.Status != step.expected {
			t.Fatalf("Expected %s, got %s", step.expected, order.Status)
		}
	}
}

func TestDesignatedDriver_PaymentFailsRetry(t *testing.T) {
	sm := NewStateMachine(ServiceTypeDesignatedDriver)
	order := &Order{ID: "dd-002", Status: StatusCreated}

	sm.ProcessEvent(order, EventDriverFound)
	sm.ProcessEvent(order, EventDriverAccepted)
	sm.ProcessEvent(order, EventDriverArrived)
	sm.ProcessEvent(order, EventVehicleInspected)
	sm.ProcessEvent(order, EventStartDriving)
	sm.ProcessEvent(order, EventArrivedDest)
	sm.ProcessEvent(order, EventVehicleHandedOver)

	// Payment fails then succeeds
	sm.ProcessEvent(order, EventPaymentFailed)
	if order.Status != StatusPaymentPending {
		t.Fatalf("Expected payment_pending, got %s", order.Status)
	}
	sm.ProcessEvent(order, EventPaymentSuccess)
	if order.Status != StatusPaid {
		t.Fatalf("Expected paid, got %s", order.Status)
	}
}

// ==========================================
// GetValidEvents Tests
// ==========================================

func TestGetValidEvents(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)
	events := sm.GetValidEvents(StatusCreated)

	if len(events) < 2 {
		t.Fatalf("Expected at least 2 valid events from Created, got %d", len(events))
	}

	// Should include DriverFound and CustomerCancelled
	found := false
	for _, e := range events {
		if e == EventDriverFound {
			found = true
		}
	}
	if !found {
		t.Fatal("Expected driver_found in valid events from created")
	}
}

func TestCanTransition(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)

	if !sm.CanTransition(StatusCreated, EventDriverFound) {
		t.Fatal("Should be able to transition from Created with DriverFound")
	}
	if sm.CanTransition(StatusPaid, EventDriverFound) {
		t.Fatal("Should NOT be able to transition from Paid with DriverFound")
	}
}

// ==========================================
// StatusHistory Tests
// ==========================================

func TestStatusHistory(t *testing.T) {
	sm := NewStateMachine(ServiceTypeRide)
	order := &Order{ID: "hist-001", Status: StatusCreated}

	sm.ProcessEvent(order, EventDriverFound)
	sm.ProcessEvent(order, EventDriverAccepted)

	if len(order.StatusHistory) != 2 {
		t.Fatalf("Expected 2 history entries, got %d", len(order.StatusHistory))
	}

	if order.StatusHistory[0].From != StatusCreated {
		t.Fatal("First entry should be from Created")
	}
	if order.StatusHistory[0].To != StatusDriverAssigned {
		t.Fatal("First entry should be to DriverAssigned")
	}
	if order.StatusHistory[1].Event != EventDriverAccepted {
		t.Fatal("Second entry event should be DriverAccepted")
	}
}
