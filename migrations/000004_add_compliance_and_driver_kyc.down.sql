-- 000004_add_compliance_and_driver_kyc.down.sql

DROP INDEX IF EXISTS idx_users_approval_status;

ALTER TABLE users
    DROP COLUMN IF EXISTS consent_terms_at,
    DROP COLUMN IF EXISTS consent_version,
    DROP COLUMN IF EXISTS id_card_number,
    DROP COLUMN IF EXISTS id_card_front_url,
    DROP COLUMN IF EXISTS id_card_back_url,
    DROP COLUMN IF EXISTS driver_license_number,
    DROP COLUMN IF EXISTS driver_license_class,
    DROP COLUMN IF EXISTS driver_license_expiry,
    DROP COLUMN IF EXISTS driver_license_front_url,
    DROP COLUMN IF EXISTS driver_license_back_url,
    DROP COLUMN IF EXISTS vehicle_registration_url,
    DROP COLUMN IF EXISTS vehicle_insurance_url,
    DROP COLUMN IF EXISTS vehicle_insurance_expiry,
    DROP COLUMN IF EXISTS approval_status,
    DROP COLUMN IF EXISTS rejection_reason,
    DROP COLUMN IF EXISTS approved_at,
    DROP COLUMN IF EXISTS approved_by;

