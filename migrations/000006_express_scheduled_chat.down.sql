-- 000006_express_scheduled_chat.down.sql

DROP INDEX IF EXISTS idx_order_messages_order;
DROP TABLE IF EXISTS order_messages;

DROP INDEX IF EXISTS idx_orders_scheduled;
ALTER TABLE orders DROP COLUMN IF EXISTS scheduled_at;

DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'orders_service_type_check'
    ) THEN
        ALTER TABLE orders DROP CONSTRAINT orders_service_type_check;
    END IF;
    ALTER TABLE orders ADD CONSTRAINT orders_service_type_check
        CHECK (service_type IN ('ride', 'food_delivery', 'grocery', 'designated_driver'));
END $$;
