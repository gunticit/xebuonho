package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	kafkago "github.com/segmentio/kafka-go"
)

// Producer wraps kafka-go Writer for publishing events
type Producer struct {
	writer *kafkago.Writer
	source string
}

// NewProducer creates a Kafka producer for a specific topic
func NewProducer(brokers []string, topic, source string) *Producer {
	return &Producer{
		writer: &kafkago.Writer{
			Addr:         kafkago.TCP(brokers...),
			Topic:        topic,
			Balancer:     &kafkago.Hash{},    // Key-based partitioning
			RequiredAcks: kafkago.RequireAll, // Wait for ALL replicas
			Async:        false,              // Synchronous for safety
			BatchTimeout: 10 * time.Millisecond,
			WriteTimeout: 10 * time.Second,
		},
		source: source,
	}
}

// Publish sends an event to Kafka
func (p *Producer) Publish(ctx context.Context, key string, eventType string, data interface{}) error {
	event, err := NewCloudEvent(eventType, p.source, data)
	if err != nil {
		return fmt.Errorf("create cloud event: %w", err)
	}

	value, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal event: %w", err)
	}

	msg := kafkago.Message{
		Key:   []byte(key),
		Value: value,
		Headers: []kafkago.Header{
			{Key: "event_type", Value: []byte(eventType)},
			{Key: "source", Value: []byte(p.source)},
			{Key: "event_id", Value: []byte(event.ID)},
		},
	}

	if err := p.writer.WriteMessages(ctx, msg); err != nil {
		return fmt.Errorf("publish event %s: %w", eventType, err)
	}

	return nil
}

// PublishAsync sends an event asynchronously (fire-and-forget for non-critical events)
func (p *Producer) PublishAsync(ctx context.Context, key string, eventType string, data interface{}) {
	go func() {
		if err := p.Publish(ctx, key, eventType, data); err != nil {
			log.Printf("[kafka] async publish failed: %v", err)
		}
	}()
}

// Close closes the producer
func (p *Producer) Close() error {
	return p.writer.Close()
}
