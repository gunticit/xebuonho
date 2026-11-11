-- 000005_business_driver_and_admin.down.sql

ALTER TABLE users
    DROP CONSTRAINT IF EXISTS chk_users_driver_kind,
    DROP COLUMN IF EXISTS driver_kind,
    DROP COLUMN IF EXISTS company_name,
    DROP COLUMN IF EXISTS company_tax_code,
    DROP COLUMN IF EXISTS business_license_number,
    DROP COLUMN IF EXISTS business_license_url,
    DROP COLUMN IF EXISTS transport_license_number,
    DROP COLUMN IF EXISTS transport_license_expiry,
    DROP COLUMN IF EXISTS transport_license_url,
    DROP COLUMN IF EXISTS employment_contract_url,
    DROP COLUMN IF EXISTS blackbox_installed,
    DROP COLUMN IF EXISTS cabin_camera_installed;

DELETE FROM users WHERE phone = '0900000001' AND role = 'admin';
