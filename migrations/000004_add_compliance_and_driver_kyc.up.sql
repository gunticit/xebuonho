-- 000004_add_compliance_and_driver_kyc.up.sql
-- Compliance with Nghị định 13/2023/NĐ-CP (PDPD) and Nghị định 10/2020/NĐ-CP (Transport regulations)

ALTER TABLE users
    -- Consent fields (Nghị định 13/2023/NĐ-CP)
    ADD COLUMN IF NOT EXISTS consent_terms_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS consent_version VARCHAR(20) DEFAULT '2026.1',

    -- Driver KYC & Vehicle details (Nghị định 10/2020/NĐ-CP)
    ADD COLUMN IF NOT EXISTS id_card_number VARCHAR(20),
    ADD COLUMN IF NOT EXISTS id_card_front_url TEXT,
    ADD COLUMN IF NOT EXISTS id_card_back_url TEXT,
    ADD COLUMN IF NOT EXISTS driver_license_number VARCHAR(30),
    ADD COLUMN IF NOT EXISTS driver_license_class VARCHAR(10), -- A1, A2, B1, B2, C
    ADD COLUMN IF NOT EXISTS driver_license_expiry DATE,
    ADD COLUMN IF NOT EXISTS driver_license_front_url TEXT,
    ADD COLUMN IF NOT EXISTS driver_license_back_url TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_registration_url TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_insurance_url TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_insurance_expiry DATE,

    -- Driver Approval Workflow
    ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'approved' CHECK (approval_status IN ('unverified', 'pending_approval', 'approved', 'rejected', 'suspended')),
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_by UUID;

CREATE INDEX IF NOT EXISTS idx_users_approval_status ON users(approval_status) WHERE role = 'driver';

-- Backfill existing demo accounts
UPDATE users SET 
    consent_terms_at = NOW(),
    consent_version = '2026.1',
    approval_status = 'approved'
WHERE approval_status IS NULL OR consent_terms_at IS NULL;

