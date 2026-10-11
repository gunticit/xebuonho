-- 000003_complete_multi_service_and_indexes.down.sql
DROP TABLE IF EXISTS wallet_transactions;
DROP TABLE IF EXISTS wallets;

DROP INDEX IF EXISTS idx_orders_service_status;
DROP INDEX IF EXISTS idx_orders_pending_matching;
DROP INDEX IF EXISTS idx_orders_dropoff_location;
DROP INDEX IF EXISTS idx_orders_pickup_location;
DROP INDEX IF EXISTS idx_merchants_location;
