-- 000003_create_merchants.up.sql
-- Merchants (Nhà hàng, Cửa hàng, Siêu thị)

CREATE TABLE IF NOT EXISTS merchants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        UUID REFERENCES users(id),
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    category        VARCHAR(50) NOT NULL,
    phone           VARCHAR(15),
    email           VARCHAR(255),
    
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    address         TEXT NOT NULL,
    
    logo_url        TEXT,
    cover_url       TEXT,
    rating          DECIMAL(3,2) DEFAULT 5.00,
    total_orders    INTEGER DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    is_verified     BOOLEAN DEFAULT FALSE,
    
    operating_hours JSONB DEFAULT '{"mon-fri":"07:00-22:00","sat-sun":"08:00-23:00"}',
    commission_rate DECIMAL(4,2) DEFAULT 20.00,
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_merchants_location ON merchants USING GIST(location);
CREATE INDEX idx_merchants_category ON merchants(category);
CREATE INDEX idx_merchants_active ON merchants(is_active);

-- Menu Items
CREATE TABLE IF NOT EXISTS menu_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    merchant_id     UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
    category_name   VARCHAR(100),
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    price           DECIMAL(12,0) NOT NULL,
    image_url       TEXT,
    is_available    BOOLEAN DEFAULT TRUE,
    preparation_time_min INTEGER DEFAULT 15,
    options         JSONB DEFAULT '[]',
    sort_order      INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_menu_merchant ON menu_items(merchant_id);
CREATE INDEX idx_menu_available ON menu_items(merchant_id, is_available);
