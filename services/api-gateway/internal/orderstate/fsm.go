package orderstate

import (
	"fmt"
)

// OrderStatus đại diện cho trạng thái đơn hàng / cuốc xe
type OrderStatus string

const (
	StatusCreated             OrderStatus = "created"
	StatusAccepted            OrderStatus = "accepted"
	StatusArriving            OrderStatus = "arriving"
	StatusArrived             OrderStatus = "arrived"
	StatusInProgress          OrderStatus = "in_progress"
	StatusCompleted           OrderStatus = "completed"
	StatusCancelledByCustomer OrderStatus = "cancelled_by_customer"
	StatusCancelledByDriver   OrderStatus = "cancelled_by_driver"
	StatusCancelled           OrderStatus = "cancelled"
)

// IsTerminal kiểm tra xem trạng thái đã kết thúc chưa (không thể chuyển đổi tiếp)
func (s OrderStatus) IsTerminal() bool {
	return s == StatusCompleted ||
		s == StatusCancelledByCustomer ||
		s == StatusCancelledByDriver ||
		s == StatusCancelled
}

// OrderStateMachine (State Pattern / FSM) kiểm soát chặt chẽ quy tắc chuyển trạng thái
type OrderStateMachine struct{}

var validTransitions = map[OrderStatus][]OrderStatus{
	StatusCreated: {
		StatusAccepted,
		StatusCancelledByCustomer,
		StatusCancelled,
	},
	StatusAccepted: {
		StatusArriving,
		StatusArrived,
		StatusCancelledByCustomer,
		StatusCancelledByDriver,
		StatusCancelled,
	},
	StatusArriving: {
		StatusArrived,
		StatusCancelledByDriver,
		StatusCancelled,
	},
	StatusArrived: {
		StatusInProgress,
		StatusCancelledByDriver,
		StatusCancelled,
	},
	StatusInProgress: {
		StatusCompleted,
		StatusCancelledByDriver,
		StatusCancelled,
	},
	StatusCompleted:           {}, // Terminal
	StatusCancelledByCustomer: {}, // Terminal
	StatusCancelledByDriver:   {}, // Terminal
	StatusCancelled:           {}, // Terminal
}

// CanTransition kiểm tra tính hợp lệ của việc chuyển từ current -> target
func CanTransition(current, target OrderStatus) bool {
	allowed, exists := validTransitions[current]
	if !exists {
		return false
	}
	for _, a := range allowed {
		if a == target {
			return true
		}
	}
	return false
}

// ValidateTransition trả về lỗi chi tiết nếu vi phạm quy tắc Finite State Machine
func ValidateTransition(currentStr, targetStr string) error {
	current := OrderStatus(currentStr)
	target := OrderStatus(targetStr)

	if current == target {
		return nil
	}

	if current.IsTerminal() {
		return fmt.Errorf("đơn hàng đã ở trạng thái kết thúc (%s), không thể chuyển sang (%s)", current, target)
	}

	if !CanTransition(current, target) {
		return fmt.Errorf("chuyển đổi trạng thái không hợp lệ: không thể chuyển từ '%s' sang '%s'", current, target)
	}

	return nil
}
