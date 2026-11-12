// Package driverstate holds transient per-driver state in gateway memory:
// the last known GPS position of every driver that reported a location update.
// Persistent state lives in Postgres; this store only serves realtime lookups
// (rider tracking, nearby driver lists) and is rebuilt as drivers report again.
package driverstate

import (
	"sync"
	"time"
)

// Point is the latest location reported by a driver.
type Point struct {
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	Speed     float64   `json:"speed,omitempty"`
	Heading   float64   `json:"heading,omitempty"`
	Battery   int       `json:"battery,omitempty"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Store struct {
	mu     sync.RWMutex
	points map[string]Point
}

// Default is the process-wide store (same global pattern as event.GetDispatcher).
var Default = NewStore()

func NewStore() *Store {
	return &Store{points: make(map[string]Point)}
}

func (s *Store) Set(driverID string, p Point) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.points[driverID] = p
}

func (s *Store) Get(driverID string) (Point, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	p, ok := s.points[driverID]
	return p, ok
}

// All returns a copy of every driver's latest point.
func (s *Store) All() map[string]Point {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make(map[string]Point, len(s.points))
	for id, p := range s.points {
		out[id] = p
	}
	return out
}
