-- 000002_add_triggers.up.sql
-- Apply updated_at triggers to merchant and order tables

-- Merchants
DROP TRIGGER IF EXISTS trg_merchants_updated_at ON merchants;
CREATE TRIGGER trg_merchants_updated_at
    BEFORE UPDATE ON merchants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Menu Items
DROP TRIGGER IF EXISTS trg_menu_items_updated_at ON menu_items;
CREATE TRIGGER trg_menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Orders
DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ==========================================
-- Composite indexes for common query patterns
-- ==========================================

-- Active orders per customer for dashboard
CREATE INDEX IF NOT EXISTS idx_orders_active_customer
    ON orders(customer_id, status)
    WHERE status NOT IN ('completed', 'cancelled_by_customer', 'cancelled_by_driver', 'paid');

-- Active orders per driver for driver app
CREATE INDEX IF NOT EXISTS idx_orders_active_driver
    ON orders(driver_id, status)
    WHERE status NOT IN ('completed', 'cancelled_by_customer', 'cancelled_by_driver', 'paid')
    AND driver_id IS NOT NULL;

-- Merchant pending orders
CREATE INDEX IF NOT EXISTS idx_orders_merchant_pending
    ON orders(merchant_id, status)
    WHERE status IN ('placed', 'merchant_confirmed', 'preparing')
    AND merchant_id IS NOT NULL;

-- Date-range analytics queries
CREATE INDEX IF NOT EXISTS idx_orders_created_type
    ON orders(created_at DESC, service_type);
