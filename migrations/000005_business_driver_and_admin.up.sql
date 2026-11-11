-- 000005_business_driver_and_admin.up.sql
-- Separate flow for business drivers (contract vehicles) per Nghị định 10/2020/NĐ-CP
-- and 47/2022/NĐ-CP (transport business license, contract badge, blackbox, cabin camera).
-- Also seeds the first admin account used by the KYC moderation panel.

ALTER TABLE users
    -- Driver kind: personal (xe cá nhân/xe máy) vs business (xe ô tô hợp đồng doanh nghiệp)
    ADD COLUMN IF NOT EXISTS driver_kind VARCHAR(20) NOT NULL DEFAULT 'personal',

    -- Business driver documents (Nghị định 10/2020 + 47/2022)
    ADD COLUMN IF NOT EXISTS company_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS company_tax_code VARCHAR(20),
    ADD COLUMN IF NOT EXISTS business_license_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS business_license_url TEXT,
    ADD COLUMN IF NOT EXISTS transport_license_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS transport_license_expiry DATE,
    ADD COLUMN IF NOT EXISTS transport_license_url TEXT,
    ADD COLUMN IF NOT EXISTS employment_contract_url TEXT,
    ADD COLUMN IF NOT EXISTS blackbox_installed BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS cabin_camera_installed BOOLEAN DEFAULT FALSE;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_driver_kind'
    ) THEN
        ALTER TABLE users ADD CONSTRAINT chk_users_driver_kind
            CHECK (driver_kind IN ('personal', 'business'));
    END IF;
END $$;

-- Backfill existing demo drivers to personal kind (default value already covers rows,
-- this keeps the intent explicit for legacy NULL-free datasets).
UPDATE users SET driver_kind = 'personal' WHERE role = 'driver' AND driver_kind IS NULL;

-- Seed first admin account for the KYC moderation panel.
-- DEMO ONLY: password is admin123 — MUST be rotated before production.
INSERT INTO users (phone, email, full_name, role, password_hash, is_verified, is_active,
                   consent_terms_at, consent_version, approval_status)
VALUES (
    '0900000001', 'admin@xebuonho.vn', 'Quản trị viên Xe Buôn Hồ', 'admin',
    '$2a$10$NeGXa85I/d8I0kPcQR6n3ORo1iyXewkWkf5PrBYWCxhF6tczPslMK',
    TRUE, TRUE, NOW(), '2026.1', 'approved'
)
ON CONFLICT (phone) DO NOTHING;
