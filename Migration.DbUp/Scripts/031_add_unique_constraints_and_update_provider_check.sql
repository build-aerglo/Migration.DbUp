-- ============================================================================
-- Add UNIQUE constraints and update provider check constraint
-- Version: 2.0.3
-- ============================================================================

-- Add UNIQUE constraint to end_user table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_end_user_user_id'
    ) THEN
ALTER TABLE end_user ADD CONSTRAINT uq_end_user_user_id UNIQUE (user_id);
END IF;
END $$;

-- Add UNIQUE constraint to user_settings table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_user_settings_user_id'
    ) THEN
ALTER TABLE user_settings ADD CONSTRAINT uq_user_settings_user_id UNIQUE (user_id);
END IF;
END $$;

-- Drop the old provider constraint
ALTER TABLE social_identities
DROP CONSTRAINT IF EXISTS chk_provider;

-- Add new constraint with exact Auth0 provider names
ALTER TABLE social_identities
    ADD CONSTRAINT chk_provider
        CHECK (provider IN ('google-oauth2', 'Facebook', 'Apple', 'GitHub', 'Twitter', 'linkedin'));


-- Add businessAddress to business Table
ALTER TABLE public.business 
     ADD COLUMN IF NOT EXISTS business_address TEXT,
    ADD COLUMN IF NOT EXISTS logo TEXT,
    ADD COLUMN IF NOT EXISTS opening_hours TEXT,
    ADD COLUMN IF NOT EXISTS business_description TEXT,
    ADD COLUMN IF NOT EXISTS qr_code_base64 TEXT,

    -- Contact Information
    ADD COLUMN IF NOT EXISTS business_email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS business_phone_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS preferred_contact_method VARCHAR(50),

    -- Business Details
    ADD COLUMN IF NOT EXISTS cac_number VARCHAR(100),
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,

    -- Credentials/Access
    ADD COLUMN IF NOT EXISTS access_username VARCHAR(255),
    ADD COLUMN IF NOT EXISTS access_number VARCHAR(255),

    -- Review & Marketing
    ADD COLUMN IF NOT EXISTS review_link TEXT,
    ADD COLUMN IF NOT EXISTS average_response_time VARCHAR(100),

    -- Statistics (Non-nullable with defaults)
    ADD COLUMN IF NOT EXISTS profile_clicks BIGINT NOT NULL DEFAULT 0,

    -- Complex Data Types (JSONB and Arrays)
    ADD COLUMN IF NOT EXISTS social_media_links JSONB,
    ADD COLUMN IF NOT EXISTS media JSONB,
    ADD COLUMN IF NOT EXISTS faqs JSONB,
    ADD COLUMN IF NOT EXISTS highlights TEXT[],
    ADD COLUMN IF NOT EXISTS tags TEXT[];


ALTER TABLE user_points
ALTER COLUMN last_login_date TYPE TIMESTAMP WITH TIME ZONE 
USING last_login_date::TIMESTAMP WITH TIME ZONE;

-- Update comment
COMMENT ON COLUMN user_points.last_login_date IS 'Last login timestamp for streak tracking (reset after 14 days gap)';

-- The index should automatically handle the new type, but let's be explicit
DROP INDEX IF EXISTS idx_user_points_last_login_date;
CREATE INDEX idx_user_points_last_login_date ON user_points(last_login_date);

