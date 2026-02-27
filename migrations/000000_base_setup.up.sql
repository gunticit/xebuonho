-- 000000_base_setup.up.sql
-- Shared base setup: PostGIS, UUID, users table, triggers
-- This should run FIRST before any service-specific migrations.

-- Extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- Users table (foundation for all FK references)
-- ==========================================
CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone           VARCHAR(15) UNIQUE,
    email           VARCHAR(255) UNIQUE,
    full_name       VARCHAR(200),
    avatar_url      TEXT,
    role            VARCHAR(20) NOT NULL DEFAULT 'rider' CHECK (role IN ('rider', 'driver', 'merchant', 'admin')),
    is_verified     BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    
    -- Driver-specific fields
    vehicle_type    VARCHAR(20),
    license_plate   VARCHAR(20),
    vehicle_model   VARCHAR(100),
    
    -- Location (latest known)
    last_location   GEOGRAPHY(POINT, 4326),
    last_location_at TIMESTAMPTZ,
    
    -- Auth
    password_hash   TEXT,
    refresh_token   TEXT,
    
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_location ON users USING GIST(last_location);

-- ==========================================
-- Auto-update updated_at trigger function
-- ==========================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
