-- 000006_express_scheduled_chat.up.sql
-- 1) Express delivery becomes a first-class service_type
-- 2) Scheduled rides: scheduled_at column + 'scheduled' status support
-- 3) Rider<->Driver chat messages per order

-- 1) Extend service_type CHECK to allow express_delivery
-- (inline CHECK in 000001 → Postgres auto-names it orders_service_type_check)
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'orders_service_type_check'
    ) THEN
        ALTER TABLE orders DROP CONSTRAINT orders_service_type_check;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'orders_service_type_check'
    ) THEN
        ALTER TABLE orders ADD CONSTRAINT orders_service_type_check
            CHECK (service_type IN ('ride', 'food_delivery', 'grocery', 'designated_driver', 'express_delivery'));
    END IF;
END $$;

-- 2) Scheduled rides
ALTER TABLE orders ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_orders_scheduled ON orders(scheduled_at) WHERE status = 'scheduled';

-- 3) Rider <-> Driver chat per order
CREATE TABLE IF NOT EXISTS order_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    sender_id   UUID NOT NULL REFERENCES users(id),
    sender_role VARCHAR(20) NOT NULL CHECK (sender_role IN ('rider', 'driver')),
    message     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_order_messages_order ON order_messages(order_id, created_at);
