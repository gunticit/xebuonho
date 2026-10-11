-- 000003_complete_multi_service_and_indexes.up.sql
-- Migration: Complete multi-service support, spatial GiST indexing, wallets and security guardrails

-- 1. Orders table extensions for Food, Grocery & Designated Driver
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(255),
ADD COLUMN IF NOT EXISTS service_type VARCHAR(50) DEFAULT 'ride',
ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS packing_fee NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS grocery_store_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS grocery_estimated_cost NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS grocery_actual_cost NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS grocery_service_fee NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS receipt_image_url TEXT,
ADD COLUMN IF NOT EXISTS receipt_hash VARCHAR(64),
ADD COLUMN IF NOT EXISTS designated_vehicle_type VARCHAR(50),
ADD COLUMN IF NOT EXISTS designated_license_plate VARCHAR(50),
ADD COLUMN IF NOT EXISTS designated_mode VARCHAR(20) DEFAULT 'solo',
ADD COLUMN IF NOT EXISTS shadow_driver_fee NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS night_surcharge NUMERIC(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS inspection_data JSONB DEFAULT '{}'::jsonb;

-- Idempotency unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_orders_idempotency_key'
    ) THEN
        ALTER TABLE orders ADD CONSTRAINT uq_orders_idempotency_key UNIQUE (idempotency_key);
    END IF;
END $$;

-- 2. Spatial Indexes (GiST) & Composite Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_merchants_location ON merchants USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_orders_pickup_location ON orders USING GIST (pickup_location);
CREATE INDEX IF NOT EXISTS idx_orders_dropoff_location ON orders USING GIST (dropoff_location);

-- Partial index for high-speed radar dispatching
CREATE INDEX IF NOT EXISTS idx_orders_pending_matching 
ON orders (status, created_at DESC) 
WHERE status = 'created';

CREATE INDEX IF NOT EXISTS idx_orders_service_status 
ON orders (service_type, status);

-- 3. Driver Capabilities Extensions
ALTER TABLE driver_capabilities
ADD COLUMN IF NOT EXISTS can_ride BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS can_food BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS can_grocery BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS can_designated BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS transmission_type VARCHAR(20) DEFAULT 'BOTH';

-- 4. Wallets & Transactions (Financial Security Guardrail)
CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    balance NUMERIC(14,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    currency VARCHAR(10) DEFAULT 'VND',
    is_locked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    amount NUMERIC(14,2) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'TOPUP', 'DEBIT_RIDE', 'EARNING_DRIVER', 'REFUND'
    reference_id VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON wallet_transactions (wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_id ON wallet_transactions (user_id, created_at DESC);

-- Seed demo wallets for test accounts
INSERT INTO wallets (user_id, balance)
VALUES 
    ('ca3065df-b201-4e92-a807-04b51354a8d3', 500000.00), -- Khách hàng demo: 500.000đ
    ('93623b04-ecc7-4654-8846-e05f72ab8069', 1250000.00) -- Tài xế demo: 1.250.000đ
ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance;
