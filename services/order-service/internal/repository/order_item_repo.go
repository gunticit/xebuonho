package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xebuonho/services/order-service/internal/model"
)

// OrderItemRepository handles order items
type OrderItemRepository struct {
	db *pgxpool.Pool
}

// NewOrderItemRepository creates a new repository
func NewOrderItemRepository(db *pgxpool.Pool) *OrderItemRepository {
	return &OrderItemRepository{db: db}
}

// CreateBatch inserts multiple order items
func (r *OrderItemRepository) CreateBatch(ctx context.Context, orderID string, items []model.OrderItem) error {
	for _, item := range items {
		query := `
			INSERT INTO order_items (order_id, menu_item_id, name, quantity, unit_price, total_price,
				options_selected, unit, notes, status)
			VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10)
		`
		optionsJSON := item.OptionsSelected
		if optionsJSON == "" {
			optionsJSON = "[]"
		}
		_, err := r.db.Exec(ctx, query,
			orderID, item.MenuItemID, item.Name, item.Quantity, item.UnitPrice,
			item.TotalPrice, optionsJSON, item.Unit, item.Notes, "pending",
		)
		if err != nil {
			return fmt.Errorf("insert order item %s: %w", item.Name, err)
		}
	}
	return nil
}

// GetByOrderID retrieves all items for an order
func (r *OrderItemRepository) GetByOrderID(ctx context.Context, orderID string) ([]model.OrderItem, error) {
	query := `
		SELECT id, order_id, menu_item_id, name, quantity, unit_price, total_price,
			options_selected::text, unit, notes, is_substituted, original_name,
			substitution_approved, status, created_at
		FROM order_items WHERE order_id = $1
		ORDER BY created_at
	`

	rows, err := r.db.Query(ctx, query, orderID)
	if err != nil {
		return nil, fmt.Errorf("get order items: %w", err)
	}
	defer rows.Close()

	var items []model.OrderItem
	for rows.Next() {
		item := model.OrderItem{}
		if err := rows.Scan(
			&item.ID, &item.OrderID, &item.MenuItemID, &item.Name,
			&item.Quantity, &item.UnitPrice, &item.TotalPrice,
			&item.OptionsSelected, &item.Unit, &item.Notes,
			&item.IsSubstituted, &item.OriginalName,
			&item.SubstitutionApproved, &item.Status, &item.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan order item: %w", err)
		}
		items = append(items, item)
	}
	return items, nil
}

// UpdateSubstitution marks an item as substituted
func (r *OrderItemRepository) UpdateSubstitution(ctx context.Context, itemID string, newName string, newPrice float64, approved *bool) error {
	query := `
		UPDATE order_items SET
			is_substituted = true,
			original_name = name,
			name = $2,
			unit_price = $3,
			total_price = $3 * quantity,
			substitution_approved = $4
		WHERE id = $1
	`
	_, err := r.db.Exec(ctx, query, itemID, newName, newPrice, approved)
	return err
}

// ConfirmSubstitution confirms or rejects a substitution
func (r *OrderItemRepository) ConfirmSubstitution(ctx context.Context, itemID string, approved bool) error {
	query := `UPDATE order_items SET substitution_approved = $2 WHERE id = $1`
	if !approved {
		// If rejected, set quantity to 0 (skip this item)
		query = `UPDATE order_items SET substitution_approved = $2, quantity = 0, total_price = 0 WHERE id = $1`
	}
	_, err := r.db.Exec(ctx, query, itemID, approved)
	return err
}
