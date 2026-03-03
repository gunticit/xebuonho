package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"bufio"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"strings"
)

// ==========================================
// Notification types
// ==========================================

type Notification struct {
	ID        string      `json:"id"`
	Type      string      `json:"type"`
	Title     string      `json:"title"`
	Message   string      `json:"message"`
	Data      interface{} `json:"data,omitempty"`
	Timestamp int64       `json:"timestamp"`
	Read      bool        `json:"read"`
}

// ==========================================
// WebSocket Hub - manages all connections
// ==========================================

type Client struct {
	conn   io.ReadWriteCloser
	writer *bufio.Writer
	send   chan []byte
	hub    *Hub
	userID string
	role   string
	mu     sync.Mutex
}

type Hub struct {
	clients    map[string]*Client // userID -> client
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
	logger     *log.Logger
	// Store recent notifications per user
	recentNotifications map[string][]Notification
	notifMu             sync.RWMutex
}

func NewHub() *Hub {
	return &Hub{
		clients:             make(map[string]*Client),
		broadcast:           make(chan []byte, 256),
		register:            make(chan *Client),
		unregister:          make(chan *Client),
		logger:              log.New(log.Writer(), "[ws-hub] ", log.LstdFlags),
		recentNotifications: make(map[string][]Notification),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.userID] = client
			h.mu.Unlock()
			h.logger.Printf("🟢 Client connected: %s [%s] (total: %d)",
				client.userID, client.role, len(h.clients))

			// Send stored notifications on connect
			h.notifMu.RLock()
			if notifs, ok := h.recentNotifications[client.userID]; ok {
				data, _ := json.Marshal(map[string]interface{}{
					"type":          "init",
					"notifications": notifs,
				})
				client.send <- data
			}
			h.notifMu.RUnlock()

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.userID]; ok {
				delete(h.clients, client.userID)
				close(client.send)
			}
			h.mu.Unlock()
			h.logger.Printf("🔴 Client disconnected: %s", client.userID)

		case message := <-h.broadcast:
			h.mu.RLock()
			for _, client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client.userID)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// SendToUser sends a notification to a specific user
func (h *Hub) SendToUser(userID string, notif Notification) {
	notif.Timestamp = time.Now().UnixMilli()
	if notif.ID == "" {
		notif.ID = generateID()
	}

	// Store notification
	h.notifMu.Lock()
	h.recentNotifications[userID] = append(h.recentNotifications[userID], notif)
	if len(h.recentNotifications[userID]) > 50 {
		h.recentNotifications[userID] = h.recentNotifications[userID][len(h.recentNotifications[userID])-50:]
	}
	h.notifMu.Unlock()

	data, err := json.Marshal(map[string]interface{}{
		"type":         "notification",
		"notification": notif,
	})
	if err != nil {
		return
	}

	h.mu.RLock()
	if client, ok := h.clients[userID]; ok {
		select {
		case client.send <- data:
		default:
		}
	}
	h.mu.RUnlock()
}

// SendToRole broadcasts to all users with a specific role
func (h *Hub) SendToRole(role string, notif Notification) {
	notif.Timestamp = time.Now().UnixMilli()
	if notif.ID == "" {
		notif.ID = generateID()
	}

	data, _ := json.Marshal(map[string]interface{}{
		"type":         "notification",
		"notification": notif,
	})

	h.mu.RLock()
	for _, client := range h.clients {
		if client.role == role || role == "all" {
			select {
			case client.send <- data:
			default:
			}
		}
	}
	h.mu.RUnlock()
}

// Broadcast sends to ALL connected clients
func (h *Hub) Broadcast(notif Notification) {
	h.SendToRole("all", notif)
}

// GetNotifications returns stored notifications for a user
func (h *Hub) GetNotifications(userID string) []Notification {
	h.notifMu.RLock()
	defer h.notifMu.RUnlock()
	return h.recentNotifications[userID]
}

// MarkRead marks a notification as read
func (h *Hub) MarkRead(userID, notifID string) {
	h.notifMu.Lock()
	defer h.notifMu.Unlock()
	for i, n := range h.recentNotifications[userID] {
		if n.ID == notifID {
			h.recentNotifications[userID][i].Read = true
			break
		}
	}
}

// GetOnlineCount returns number of connected clients
func (h *Hub) GetOnlineCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// ==========================================
// WebSocket HTTP Upgrade Handler
// ==========================================

func (h *Hub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	role := r.URL.Query().Get("role")
	if userID == "" {
		userID = "anonymous-" + generateID()[:8]
	}
	if role == "" {
		role = "rider"
	}

	// WebSocket handshake
	conn, err := upgradeHTTP(w, r)
	if err != nil {
		h.logger.Printf("Upgrade failed: %v", err)
		return
	}

	client := &Client{
		conn:   conn,
		writer: bufio.NewWriter(conn),
		send:   make(chan []byte, 64),
		hub:    h,
		userID: userID,
		role:   role,
	}

	h.register <- client

	go client.writePump()
	go client.readPump()
}

// ==========================================
// Client read/write pumps
// ==========================================

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	buf := make([]byte, 4096)
	for {
		n, err := c.conn.Read(buf)
		if err != nil {
			break
		}

		// Decode WebSocket frame
		payload, opcode := decodeFrame(buf[:n])
		if opcode == 8 { // close
			break
		}
		if opcode == 9 { // ping
			c.mu.Lock()
			writeFrame(c.writer, 10, payload) // pong
			c.writer.Flush()
			c.mu.Unlock()
			continue
		}

		// Handle client messages (e.g. mark_read)
		var msg map[string]interface{}
		if err := json.Unmarshal(payload, &msg); err == nil {
			if msg["type"] == "mark_read" {
				if id, ok := msg["id"].(string); ok {
					c.hub.MarkRead(c.userID, id)
				}
			}
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			if !ok {
				c.mu.Lock()
				writeFrame(c.writer, 8, nil)
				c.writer.Flush()
				c.mu.Unlock()
				return
			}
			c.mu.Lock()
			writeFrame(c.writer, 1, message)
			c.writer.Flush()
			c.mu.Unlock()

		case <-ticker.C:
			c.mu.Lock()
			writeFrame(c.writer, 9, []byte("ping"))
			c.writer.Flush()
			c.mu.Unlock()
		}
	}
}

// ==========================================
// WebSocket frame encoding/decoding (RFC 6455)
// ==========================================

func upgradeHTTP(w http.ResponseWriter, r *http.Request) (io.ReadWriteCloser, error) {
	if !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
		return nil, fmt.Errorf("not a websocket request")
	}

	key := r.Header.Get("Sec-WebSocket-Key")
	if key == "" {
		return nil, fmt.Errorf("missing Sec-WebSocket-Key")
	}

	accept := computeAcceptKey(key)

	hj, ok := w.(http.Hijacker)
	if !ok {
		return nil, fmt.Errorf("server doesn't support hijacking")
	}

	conn, bufrw, err := hj.Hijack()
	if err != nil {
		return nil, err
	}

	response := "HTTP/1.1 101 Switching Protocols\r\n" +
		"Upgrade: websocket\r\n" +
		"Connection: Upgrade\r\n" +
		"Sec-WebSocket-Accept: " + accept + "\r\n\r\n"

	bufrw.WriteString(response)
	bufrw.Flush()

	return conn, nil
}

func computeAcceptKey(key string) string {
	h := sha1.New()
	h.Write([]byte(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

func writeFrame(w *bufio.Writer, opcode byte, payload []byte) {
	// FIN + opcode
	w.WriteByte(0x80 | opcode)

	length := len(payload)
	if length <= 125 {
		w.WriteByte(byte(length))
	} else if length <= 65535 {
		w.WriteByte(126)
		binary.Write(w, binary.BigEndian, uint16(length))
	} else {
		w.WriteByte(127)
		binary.Write(w, binary.BigEndian, uint64(length))
	}

	w.Write(payload)
}

func decodeFrame(data []byte) (payload []byte, opcode byte) {
	if len(data) < 2 {
		return nil, 0
	}

	opcode = data[0] & 0x0F
	masked := (data[1] & 0x80) != 0
	length := uint64(data[1] & 0x7F)

	offset := 2
	if length == 126 {
		if len(data) < 4 {
			return nil, 0
		}
		length = uint64(binary.BigEndian.Uint16(data[2:4]))
		offset = 4
	} else if length == 127 {
		if len(data) < 10 {
			return nil, 0
		}
		length = binary.BigEndian.Uint64(data[2:10])
		offset = 10
	}

	if masked {
		if len(data) < offset+4+int(length) {
			return nil, opcode
		}
		mask := data[offset : offset+4]
		offset += 4
		payload = make([]byte, length)
		for i := uint64(0); i < length; i++ {
			payload[i] = data[offset+int(i)] ^ mask[i%4]
		}
	} else {
		end := offset + int(length)
		if end > len(data) {
			end = len(data)
		}
		payload = data[offset:end]
	}

	return payload, opcode
}

func generateID() string {
	b := make([]byte, 8)
	rand.Read(b)
	return fmt.Sprintf("%x", b)
}
