-- 000001_create_orders.up.sql
-- Unified Orders table (all 4 service types)

CREATE TABLE IF NOT EXISTS orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key VARCHAR(64) UNIQUE NOT NULL,
    
    -- Service type
    service_type    VARCHAR(30) NOT NULL CHECK (service_type IN (
        'ride', 'food_delivery', 'grocery', 'designated_driver'
    )),
    
    -- Participants
    customer_id     UUID NOT NULL REFERENCES users(id),
    driver_id       UUID REFERENCES users(id),
    merchant_id     UUID, -- FK to merchants in merchant-service DB
    shadow_driver_id UUID REFERENCES users(id),
    
    -- Locations
    pickup_location  GEOGRAPHY(POINT, 4326) NOT NULL,
    pickup_address   TEXT NOT NULL,
    dropoff_location GEOGRAPHY(POINT, 4326) NOT NULL,
    dropoff_address  TEXT NOT NULL,
    
    -- Vehicle
    vehicle_type    VARCHAR(20),
    
    -- State
    status          VARCHAR(40) NOT NULL DEFAULT 'created',
    
    -- Pricing
    items_total      DECIMAL(12,0) DEFAULT 0,
    delivery_fee     DECIMAL(12,0) DEFAULT 0,
    service_fee      DECIMAL(12,0) DEFAULT 0,
    surge_multiplier DECIMAL(3,2) DEFAULT 1.00,
    discount_amount  DECIMAL(12,0) DEFAULT 0,
    fare_estimate    DECIMAL(12,0) NOT NULL,
    fare_final       DECIMAL(12,0),
    
    -- Promo
    promo_code      VARCHAR(20),
    payment_method  VARCHAR(20) DEFAULT 'cash',
    
    -- Distance & Time
    distance_km     DECIMAL(10,2),
    duration_minutes INTEGER,
    
    -- Timestamps
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    accepted_at      TIMESTAMPTZ,
    picked_up_at     TIMESTAMPTZ,
    delivered_at     TIMESTAMPTZ,
    completed_at     TIMESTAMPTZ,
    cancelled_at     TIMESTAMPTZ,
    cancelled_by     VARCHAR(20),
    cancel_reason    TEXT,
    
    -- Flexible metadata per service_type
    metadata        JSONB DEFAULT '{}',
    
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_service_type ON orders(service_type);
CREATE INDEX idx_orders_customer ON orders(customer_id, created_at DESC);
CREATE INDEX idx_orders_driver ON orders(driver_id, created_at DESC);
CREATE INDEX idx_orders_merchant ON orders(merchant_id, created_at DESC);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_pickup ON orders USING GIST(pickup_location);
CREATE INDEX idx_orders_dropoff ON orders USING GIST(dropoff_location);
CREATE INDEX idx_orders_idempotency ON orders(idempotency_key);

-- Order Items (Food Delivery & Grocery)
CREATE TABLE IF NOT EXISTS order_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id    UUID,
    
    name            VARCHAR(200) NOT NULL,
    quantity        INTEGER NOT NULL DEFAULT 1,
    unit_price      DECIMAL(12,0) NOT NULL,
    total_price     DECIMAL(12,0) NOT NULL,
    options_selected JSONB DEFAULT '[]',
    
    -- Grocery specific
    unit            VARCHAR(20),
    notes           TEXT,
    is_substituted   BOOLEAN DEFAULT FALSE,
    original_name    VARCHAR(200),
    substitution_approved BOOLEAN,
    status          VARCHAR(20) DEFAULT 'pending',
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);

-- Vehicle Inspections (Designated Driver)
CREATE TABLE IF NOT EXISTS vehicle_inspections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID NOT NULL REFERENCES orders(id),
    driver_id       UUID NOT NULL REFERENCES users(id),
    
    license_plate   VARCHAR(20) NOT NULL,
    vehicle_model   VARCHAR(100),
    vehicle_color   VARCHAR(30),
    odometer_km     INTEGER,
    fuel_level      VARCHAR(20),
    
    photo_front_url TEXT,
    photo_back_url  TEXT,
    photo_left_url  TEXT,
    photo_right_url TEXT,
    existing_damages TEXT,
    
    inspection_at   TIMESTAMPTZ DEFAULT NOW(),
    type            VARCHAR(10) NOT NULL CHECK (type IN ('pickup', 'dropoff'))
);

CREATE INDEX idx_inspections_order ON vehicle_inspections(order_id);

-- Driver Capabilities
CREATE TABLE IF NOT EXISTS driver_capabilities (
    driver_id       UUID NOT NULL REFERENCES users(id),
    service_type    VARCHAR(30) NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    verified_at     TIMESTAMPTZ,
    has_car_license  BOOLEAN DEFAULT FALSE,
    has_bike         BOOLEAN DEFAULT FALSE,
    has_foldable_bike BOOLEAN DEFAULT FALSE,
    max_grocery_value DECIMAL(12,0),
    PRIMARY KEY (driver_id, service_type)
);

CREATE INDEX idx_driver_caps_type ON driver_capabilities(service_type, is_active);
