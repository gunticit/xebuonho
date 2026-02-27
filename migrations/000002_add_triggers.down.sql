-- 000002_add_triggers.down.sql
DROP INDEX IF EXISTS idx_orders_created_type;
DROP INDEX IF EXISTS idx_orders_merchant_pending;
DROP INDEX IF EXISTS idx_orders_active_driver;
DROP INDEX IF EXISTS idx_orders_active_customer;
DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
DROP TRIGGER IF EXISTS trg_menu_items_updated_at ON menu_items;
DROP TRIGGER IF EXISTS trg_merchants_updated_at ON merchants;
