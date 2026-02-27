package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	kafkago "github.com/segmentio/kafka-go"
)

// EventHandler handles a single Kafka event
type EventHandler func(ctx context.Context, event CloudEvent) error

// Consumer wraps kafka-go Reader for consuming events
type Consumer struct {
	reader   *kafkago.Reader
	handlers map[string]EventHandler
}

// NewConsumer creates a Kafka consumer for a consumer group
func NewConsumer(brokers []string, topic, groupID string) *Consumer {
	return &Consumer{
		reader: kafkago.NewReader(kafkago.ReaderConfig{
			Brokers:        brokers,
			Topic:          topic,
			GroupID:        groupID,
			MinBytes:       1e3,  // 1KB
			MaxBytes:       10e6, // 10MB
			CommitInterval: time.Second,
			StartOffset:    kafkago.LastOffset,
			MaxWait:        3 * time.Second,
		}),
		handlers: make(map[string]EventHandler),
	}
}

// On registers a handler for a specific event type
func (c *Consumer) On(eventType string, handler EventHandler) {
	c.handlers[eventType] = handler
}

// Listen starts consuming events (blocking)
func (c *Consumer) Listen(ctx context.Context) error {
	log.Printf("[kafka-consumer] Listening on topic: %s, group: %s",
		c.reader.Config().Topic, c.reader.Config().GroupID)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		msg, err := c.reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return nil // Context cancelled, graceful shutdown
			}
			log.Printf("[kafka-consumer] read error: %v", err)
			continue
		}

		// Parse CloudEvent
		var event CloudEvent
		if err := json.Unmarshal(msg.Value, &event); err != nil {
			log.Printf("[kafka-consumer] unmarshal error: %v", err)
			continue
		}

		// Find handler
		handler, ok := c.handlers[event.Type]
		if !ok {
			// Check headers for event type
			for _, h := range msg.Headers {
				if h.Key == "event_type" {
					handler, ok = c.handlers[string(h.Value)]
					break
				}
			}
		}

		if handler != nil {
			if err := c.processWithRetry(ctx, event, handler, 3); err != nil {
				log.Printf("[kafka-consumer] FAILED event %s (id=%s): %v", event.Type, event.ID, err)
				// In production: push to DLQ topic
			}
		}
	}
}

// processWithRetry retries event processing with exponential backoff
func (c *Consumer) processWithRetry(ctx context.Context, event CloudEvent, handler EventHandler, maxRetries int) error {
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if err := handler(ctx, event); err != nil {
			lastErr = err
			if attempt < maxRetries {
				backoff := time.Duration(1<<attempt) * time.Second
				log.Printf("[kafka-consumer] retry %d/%d for %s: %v (backoff: %v)",
					attempt+1, maxRetries, event.ID, err, backoff)
				time.Sleep(backoff)
				continue
			}
		} else {
			return nil
		}
	}
	return fmt.Errorf("exhausted %d retries: %w", maxRetries, lastErr)
}

// Close closes the consumer
func (c *Consumer) Close() error {
	return c.reader.Close()
}
