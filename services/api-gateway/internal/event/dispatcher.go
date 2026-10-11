package event

import (
	"context"
	"log"
	"sync"
	"time"
)

// EventType loại sự kiện hệ thống
type EventType string

const (
	EventOrderCreated        EventType = "order.created"
	EventOrderAccepted       EventType = "order.accepted"
	EventOrderStatusChanged  EventType = "order.status_changed"
	EventDriverStatusToggled EventType = "driver.toggled"
)

// Event cấu trúc dữ liệu của một sự kiện
type Event struct {
	ID        string      `json:"id"`
	Type      EventType   `json:"type"`
	Payload   interface{} `json:"payload"`
	Timestamp time.Time   `json:"timestamp"`
}

// EventHandler (Observer interface) hàm lắng nghe sự kiện
type EventHandler func(ctx context.Context, e Event) error

// Dispatcher (Observer / Pub-Sub Pattern) quản lý đăng ký và phân phối sự kiện
type Dispatcher struct {
	mu        sync.RWMutex
	listeners map[EventType][]EventHandler
}

var globalDispatcher *Dispatcher
var once sync.Once

// GetDispatcher trả về singleton instance của Dispatcher
func GetDispatcher() *Dispatcher {
	once.Do(func() {
		globalDispatcher = &Dispatcher{
			listeners: make(map[EventType][]EventHandler),
		}
	})
	return globalDispatcher
}

// Subscribe đăng ký lắng nghe sự kiện
func (d *Dispatcher) Subscribe(eventType EventType, handler EventHandler) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.listeners[eventType] = append(d.listeners[eventType], handler)
}

// Dispatch phát tán sự kiện tới tất cả các observers bất đồng bộ
func (d *Dispatcher) Dispatch(ctx context.Context, e Event) {
	d.mu.RLock()
	handlers, exists := d.listeners[e.Type]
	d.mu.RUnlock()

	if !exists || len(handlers) == 0 {
		return
	}

	for _, h := range handlers {
		handlerFunc := h
		go func() {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("[event-dispatcher] panic in event handler for %s: %v", e.Type, r)
				}
			}()
			if err := handlerFunc(ctx, e); err != nil {
				log.Printf("[event-dispatcher] error handling event %s: %v", e.Type, err)
			}
		}()
	}
}
