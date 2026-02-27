DROP INDEX IF EXISTS idx_driver_caps_type;
DROP TABLE IF EXISTS driver_capabilities;

DROP INDEX IF EXISTS idx_inspections_order;
DROP TABLE IF EXISTS vehicle_inspections;

DROP INDEX IF EXISTS idx_order_items_order;
DROP TABLE IF EXISTS order_items;

DROP INDEX IF EXISTS idx_orders_idempotency;
DROP INDEX IF EXISTS idx_orders_dropoff;
DROP INDEX IF EXISTS idx_orders_pickup;
DROP INDEX IF EXISTS idx_orders_status;
DROP INDEX IF EXISTS idx_orders_merchant;
DROP INDEX IF EXISTS idx_orders_driver;
DROP INDEX IF EXISTS idx_orders_customer;
DROP INDEX IF EXISTS idx_orders_service_type;
DROP TABLE IF EXISTS orders;
