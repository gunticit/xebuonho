package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/xebuonho/services/merchant-service/internal/model"
)

// MenuRepository handles menu item database operations
type MenuRepository struct {
	db *pgxpool.Pool
}

// NewMenuRepository creates a new menu repository
func NewMenuRepository(db *pgxpool.Pool) *MenuRepository {
	return &MenuRepository{db: db}
}

// Create inserts a new menu item
func (r *MenuRepository) Create(ctx context.Context, input model.CreateMenuItemInput) (*model.MenuItem, error) {
	optionsJSON, err := json.Marshal(input.Options)
	if err != nil {
		return nil, fmt.Errorf("marshal options: %w", err)
	}

	query := `
		INSERT INTO menu_items (merchant_id, category_name, name, description, price, image_url, preparation_time_min, options)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, merchant_id, category_name, name, description, price, image_url,
			is_available, preparation_time_min, options::text, sort_order, created_at, updated_at
	`

	item := &model.MenuItem{}
	var optionsStr string
	err = r.db.QueryRow(ctx, query,
		input.MerchantID, input.CategoryName, input.Name, input.Description,
		input.Price, input.ImageURL, input.PreparationTime, optionsJSON,
	).Scan(
		&item.ID, &item.MerchantID, &item.CategoryName, &item.Name,
		&item.Description, &item.Price, &item.ImageURL, &item.IsAvailable,
		&item.PreparationTime, &optionsStr, &item.SortOrder,
		&item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create menu item: %w", err)
	}

	json.Unmarshal([]byte(optionsStr), &item.Options)
	return item, nil
}

// GetByID retrieves a menu item by ID
func (r *MenuRepository) GetByID(ctx context.Context, id string) (*model.MenuItem, error) {
	query := `
		SELECT id, merchant_id, category_name, name, description, price, image_url,
			is_available, preparation_time_min, options::text, sort_order, created_at, updated_at
		FROM menu_items WHERE id = $1
	`

	item := &model.MenuItem{}
	var optionsStr string
	err := r.db.QueryRow(ctx, query, id).Scan(
		&item.ID, &item.MerchantID, &item.CategoryName, &item.Name,
		&item.Description, &item.Price, &item.ImageURL, &item.IsAvailable,
		&item.PreparationTime, &optionsStr, &item.SortOrder,
		&item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("menu item not found: %s", id)
		}
		return nil, fmt.Errorf("get menu item: %w", err)
	}

	json.Unmarshal([]byte(optionsStr), &item.Options)
	return item, nil
}

// GetMenuByMerchant retrieves all menu items grouped by category
func (r *MenuRepository) GetMenuByMerchant(ctx context.Context, merchantID string) ([]model.MenuCategory, error) {
	query := `
		SELECT id, merchant_id, category_name, name, description, price, image_url,
			is_available, preparation_time_min, options::text, sort_order, created_at, updated_at
		FROM menu_items
		WHERE merchant_id = $1
		ORDER BY category_name, sort_order, name
	`

	rows, err := r.db.Query(ctx, query, merchantID)
	if err != nil {
		return nil, fmt.Errorf("query menu: %w", err)
	}
	defer rows.Close()

	categoryMap := make(map[string]*model.MenuCategory)
	var categoryOrder []string

	for rows.Next() {
		item := model.MenuItem{}
		var optionsStr string
		if err := rows.Scan(
			&item.ID, &item.MerchantID, &item.CategoryName, &item.Name,
			&item.Description, &item.Price, &item.ImageURL, &item.IsAvailable,
			&item.PreparationTime, &optionsStr, &item.SortOrder,
			&item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan menu item: %w", err)
		}

		json.Unmarshal([]byte(optionsStr), &item.Options)

		cat, exists := categoryMap[item.CategoryName]
		if !exists {
			cat = &model.MenuCategory{Name: item.CategoryName}
			categoryMap[item.CategoryName] = cat
			categoryOrder = append(categoryOrder, item.CategoryName)
		}
		cat.Items = append(cat.Items, item)
	}

	categories := make([]model.MenuCategory, 0, len(categoryOrder))
	for _, name := range categoryOrder {
		categories = append(categories, *categoryMap[name])
	}
	return categories, nil
}

// Update updates a menu item
func (r *MenuRepository) Update(ctx context.Context, id, name, description, imageURL string, price float64, isAvailable bool) (*model.MenuItem, error) {
	query := `
		UPDATE menu_items SET
			name = COALESCE(NULLIF($2, ''), name),
			description = COALESCE(NULLIF($3, ''), description),
			price = CASE WHEN $4 > 0 THEN $4 ELSE price END,
			image_url = COALESCE(NULLIF($5, ''), image_url),
			is_available = $6,
			updated_at = NOW()
		WHERE id = $1
		RETURNING id, merchant_id, category_name, name, description, price, image_url,
			is_available, preparation_time_min, options::text, sort_order, created_at, updated_at
	`

	item := &model.MenuItem{}
	var optionsStr string
	err := r.db.QueryRow(ctx, query, id, name, description, price, imageURL, isAvailable).Scan(
		&item.ID, &item.MerchantID, &item.CategoryName, &item.Name,
		&item.Description, &item.Price, &item.ImageURL, &item.IsAvailable,
		&item.PreparationTime, &optionsStr, &item.SortOrder,
		&item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update menu item: %w", err)
	}

	json.Unmarshal([]byte(optionsStr), &item.Options)
	return item, nil
}

// ToggleAvailability toggles a menu item's availability
func (r *MenuRepository) ToggleAvailability(ctx context.Context, id string, available bool) (*model.MenuItem, error) {
	return r.Update(ctx, id, "", "", "", 0, available)
}

// ValidateItems checks if menu items are available and returns their details
func (r *MenuRepository) ValidateItems(ctx context.Context, merchantID string, itemIDs []string) ([]model.MenuItem, error) {
	query := `
		SELECT id, merchant_id, category_name, name, description, price, image_url,
			is_available, preparation_time_min, options::text, sort_order, created_at, updated_at
		FROM menu_items
		WHERE merchant_id = $1 AND id = ANY($2)
	`

	rows, err := r.db.Query(ctx, query, merchantID, itemIDs)
	if err != nil {
		return nil, fmt.Errorf("validate items: %w", err)
	}
	defer rows.Close()

	var items []model.MenuItem
	for rows.Next() {
		item := model.MenuItem{}
		var optionsStr string
		if err := rows.Scan(
			&item.ID, &item.MerchantID, &item.CategoryName, &item.Name,
			&item.Description, &item.Price, &item.ImageURL, &item.IsAvailable,
			&item.PreparationTime, &optionsStr, &item.SortOrder,
			&item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan validate item: %w", err)
		}
		json.Unmarshal([]byte(optionsStr), &item.Options)
		items = append(items, item)
	}

	return items, nil
}
